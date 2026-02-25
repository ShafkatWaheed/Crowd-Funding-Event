"""
Event CRUD: auto_transition_status, get_by_id, get_or_404, publish_event, list_events, list_events_for_map, create, update.
"""
import math
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import func, select, and_, or_, exists
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event, EventOrganizer, EventDiscount, OrganizerCustomerHistory, EventStatus, RegistrationType
from app.models.discount_strategy import DiscountStrategy, EventDiscountStrategyLink
from app.models.registration import Registration, RegistrationStatus
from app.models.venue import Venue
from app.models.user import User
from app.models.ticket import TicketTier, TicketSale, UserEventDiscount
from app.models.funding import Funding, FundingStatus
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError

from app.services.event.permissions import user_can_edit_event

async def auto_transition_status(db: AsyncSession, event: Event) -> Event:
    """
    Check time-based state transitions and apply them.
    Called on every event fetch to keep status current.

    Lifecycle:
      approved → (funding_end_at passes):
        - If start_time set → waiting_event_date (organizer must manually start selling)
        - If start_time NOT set → waiting_event_date (deadline = funding_end + grace days)
      approved (no funding, event date set) → stays approved until start_time
      waiting_event_date → (organizer clicks "Start Selling") → selling_tickets
      selling_tickets / approved → (start_time reaches now) → live
      live → (end_time reaches now) → completed
      waiting_event_date → (event_date_deadline passes, no start_time) → cancelled + refund
    """
    import logging
    from datetime import timedelta
    from app.services import platform_settings as settings_svc

    log = logging.getLogger(__name__)
    now = datetime.now(timezone.utc)
    changed = False
    previous_status = event.status

    def _tz(dt: datetime | None) -> datetime | None:
        if dt is None:
            return None
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)

    try:
        status = event.status

        # ── approved → check funding end / non-funded transitions ──
        if status == EventStatus.approved:
            funding_end = _tz(event.funding_end_at)
            if funding_end is not None and now >= funding_end:
                grace_days = await settings_svc.get_int(db, "event_date_grace_days")
                if event.event_date_deadline is None:
                    event.event_date_deadline = funding_end + timedelta(days=grace_days)
                event.status = EventStatus.waiting_event_date
                changed = True
            elif funding_end is None and event.start_time is not None and event.ticket_strategy_id is not None:
                has_tiers = (await db.execute(
                    select(TicketTier.id).where(TicketTier.event_id == event.id).limit(1)
                )).scalar_one_or_none()
                if has_tiers is not None:
                    event.status = EventStatus.selling_tickets
                    event.ticket_selling_started_at = now
                    changed = True

        # ── waiting_event_date → check if deadline passed ──
        if status == EventStatus.waiting_event_date:
            if event.event_date_deadline is not None and now >= _tz(event.event_date_deadline) and event.start_time is None:
                event.status = EventStatus.cancelled
                event.cancellation_reason = "Event date was not set within the required deadline. Pledges refunded."
                from app.services import funding as funding_service
                await funding_service.refund_all_pledges_for_event(db, event_id=event.id, guest_refund=False)
                from app.services import email_notifications as email_notify
                import asyncio
                asyncio.ensure_future(email_notify.notify_event_cancelled(
                    db,
                    event_id=event.id,
                    event_title=event.title or f"Event #{event.id}",
                    reason=event.cancellation_reason,
                    event_date=event.start_time,
                ))
                changed = True

        # ── selling_tickets / approved → check if event started ──
        if event.status in (EventStatus.selling_tickets, EventStatus.approved):
            start = _tz(event.start_time)
            if start is not None and now >= start:
                event.status = EventStatus.live
                changed = True
                from sqlalchemy import update as sql_update
                from app.models.funding import Funding, FundingStatus
                await db.execute(
                    sql_update(Funding)
                    .where(
                        Funding.event_id == event.id,
                        Funding.status == FundingStatus.pledged,
                        Funding.reserved_spots > 0,
                    )
                    .values(reserved_spots=0)
                )

        # ── live → check if event ended ──
        if event.status == EventStatus.live:
            end = _tz(event.end_time)
            if end is not None and now >= end:
                event.status = EventStatus.completed
                changed = True

    except Exception as exc:
        log.exception("Auto-transition failed for event %s (was %s): %s", event.id, previous_status.value, exc)
        event.status = EventStatus.under_review
        event.review_notes = f"Auto-transition from '{previous_status.value}' failed: {exc}"
        event.review_log = (event.review_log or []) + [{
            "timestamp": now.isoformat(),
            "actor": "system",
            "action": "entered_review",
            "from_status": previous_status.value,
            "to_status": "under_review",
            "message": f"Auto-transition failed: {exc}",
        }]
        changed = True
        try:
            from app.services import notification_service as notif_svc
            from app.models.notification import NotificationType
            await notif_svc.create_notification(
                db, user_id=event.organizer_id,
                type=NotificationType.event_under_review,
                title="Event Under Review",
                message=f'Your event "{event.title}" needs attention. An automatic transition failed: {exc}. An admin will review it shortly.',
                data={"event_id": event.id},
            )
        except Exception:
            log.exception("Failed to send under_review notification for event %s", event.id)

    if changed:
        await db.flush()

    return event


async def get_by_id(
    db: AsyncSession,
    event_id: int,
    *,
    load_venue: bool = False,
    load_organizer: bool = False,
) -> Event | None:
    """Load event by id. Returns None if not found."""
    q = select(Event).where(Event.id == event_id)
    if load_venue:
        q = q.options(selectinload(Event.venue), selectinload(Event.ticket_strategy), selectinload(Event.organizer))
    elif load_organizer:
        q = q.options(selectinload(Event.organizer))
    result = await db.execute(q)
    event = result.scalar_one_or_none()
    if event is not None:
        event = await auto_transition_status(db, event)
    return event


async def get_or_404(db: AsyncSession, event_id: int) -> Event:
    """Load event by id or raise 404."""
    event = await get_by_id(db, event_id)
    if not event:
        raise NotFoundError("Event", event_id)
    return event


async def publish_event(db: AsyncSession, event_id: int, user: User) -> Event:
    """
    Publish a draft event (draft → approved). No admin approval needed.
    Only the organizer (or admin) can publish; event must be in draft status.
    At least one of funding_end_at or start_time must be set.
    """
    event = await get_or_404(db, event_id)
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot publish this event")
    if event.status != EventStatus.draft:
        raise ConflictError("Only draft events can be published")
    if event.start_time is None and event.funding_end_at is None:
        raise ConflictError("Set at least one of event date or funding deadline before publishing")
    event.status = EventStatus.approved
    await db.flush()
    await db.refresh(event)
    return event


async def list_events(
    db: AsyncSession,
    *,
    search: str | None = None,
    city: str | None = None,
    status: str | None = None,
    live: bool | None = None,
    registration_type: str | None = None,
    organizer_id: int | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    has_funding: bool | None = None,
    has_tickets: bool | None = None,
    min_capacity: int | None = None,
    max_capacity: int | None = None,
    genre: str | None = None,
    community_rules: bool | None = None,
    include_all_statuses: bool = False,
    sponsorship_only: bool = False,
    offset: int = 0,
    limit: int | None = None,
) -> Sequence[Event]:
    """List events with optional filters. include_all_statuses=True skips the default hidden-status filter (for organizer/admin)."""
    conditions = []
    q = select(Event)
    need_venue_join = city is not None
    if search is not None and search.strip():
        need_venue_join = True
    if need_venue_join:
        q = q.outerjoin(Event.venue)
    if city is not None:
        conditions.append(Venue.city == city)
    if search is not None and search.strip():
        search_term = f"%{search.strip()}%"
        conditions.append(
            or_(
                Event.title.ilike(search_term),
                (Event.description.isnot(None)) & (Event.description.ilike(search_term)),
                Venue.name.ilike(search_term),
                Venue.city.ilike(search_term),
                Venue.address.ilike(search_term),
            )
        )
    if status is not None:
        try:
            status_enum = EventStatus(status)
        except ValueError:
            return []
        conditions.append(Event.status == status_enum)
    elif not include_all_statuses and organizer_id is None:
        conditions.append(
            Event.status.notin_([
                EventStatus.draft, EventStatus.pending_approval,
                EventStatus.cancelled, EventStatus.completed,
            ])
        )
    if live is True:
        now = datetime.now(timezone.utc)
        conditions.append(Event.start_time.isnot(None))
        conditions.append(Event.start_time <= now)
        conditions.append(Event.end_time.isnot(None))
        conditions.append(Event.end_time >= now)
        conditions.append(Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live]))
    if registration_type is not None:
        try:
            reg_type = RegistrationType(registration_type)
        except ValueError:
            return []
        conditions.append(Event.registration_type == reg_type)
    if organizer_id is not None:
        conditions.append(Event.organizer_id == organizer_id)
    if date_from is not None:
        conditions.append(Event.start_time.isnot(None))
        conditions.append(Event.start_time >= date_from)
    if date_to is not None:
        conditions.append(Event.start_time.isnot(None))
        conditions.append(Event.start_time <= date_to)
    if has_funding is True:
        conditions.append(
            or_(Event.funding_goal_cents.isnot(None), Event.funding_end_at.isnot(None))
        )
    if has_funding is False:
        conditions.append(Event.funding_goal_cents.is_(None))
        conditions.append(Event.funding_end_at.is_(None))
    if has_tickets is True:
        conditions.append(exists(select(1).where(TicketTier.event_id == Event.id)))
    if has_tickets is False:
        conditions.append(~exists(select(1).where(TicketTier.event_id == Event.id)))
    if min_capacity is not None:
        conditions.append(Event.max_capacity >= min_capacity)
    if max_capacity is not None:
        conditions.append(Event.max_capacity <= max_capacity)
    if genre is not None:
        conditions.append(Event.genre == genre)
    if community_rules is not None:
        conditions.append(Event.community_rules == community_rules)
    if sponsorship_only:
        from app.models.sponsor import SponsorshipCategory
        conditions.append(exists(
            select(SponsorshipCategory.id).where(
                SponsorshipCategory.event_id == Event.id,
                SponsorshipCategory.is_template == False,
            )
        ))
    if conditions:
        q = q.where(and_(*conditions))
    q = q.options(selectinload(Event.venue), selectinload(Event.ticket_strategy), selectinload(Event.organizer)).order_by(Event.start_time.asc())
    if offset:
        q = q.offset(offset)
    if limit is not None:
        q = q.limit(limit)
    result = await db.execute(q)
    return result.scalars().unique().all()


async def list_events_for_map(
    db: AsyncSession,
    *,
    city: str | None = None,
    live: bool | None = None,
    lat: float | None = None,
    lng: float | None = None,
    radius_km: float | None = None,
    organizer_id: int | None = None,
    search: str | None = None,
    genre: str | None = None,
    status: str | None = None,
) -> Sequence[Event]:
    """
    List events suitable for map markers: have lat/lng, not draft/pending/cancelled.
    Optional city (via venue), live filter, lat/lng/radius_km (approximate bbox),
    organizer_id, search, genre, and status filters.
    """
    conditions = [
        Event.lat.isnot(None),
        Event.lng.isnot(None),
    ]
    if organizer_id is not None:
        conditions.append(Event.organizer_id == organizer_id)
    if status is not None:
        try:
            status_enum = EventStatus(status)
        except ValueError:
            return []
        conditions.append(Event.status == status_enum)
    elif organizer_id is None:
        conditions.append(
            Event.status.notin_([
                EventStatus.draft, EventStatus.pending_approval,
                EventStatus.cancelled, EventStatus.completed,
            ]),
        )
    need_venue_join = city is not None
    if search is not None and search.strip():
        search_term = f"%{search.strip()}%"
        need_venue_join = True
        conditions.append(
            or_(
                Event.title.ilike(search_term),
                Venue.name.ilike(search_term),
                Venue.city.ilike(search_term),
                Venue.address.ilike(search_term),
            )
        )
    if genre is not None:
        conditions.append(Event.genre == genre)
    q = select(Event)
    if need_venue_join:
        q = q.outerjoin(Event.venue)
    if city is not None:
        conditions.append(Venue.city == city)
    if live is True:
        now = datetime.now(timezone.utc)
        conditions.append(Event.start_time.isnot(None))
        conditions.append(Event.start_time <= now)
        conditions.append(Event.end_time.isnot(None))
        conditions.append(Event.end_time >= now)
        conditions.append(Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live]))
    if lat is not None and lng is not None and radius_km is not None and radius_km > 0:
        # Approximate bbox: 1 deg lat ~ 111 km; 1 deg lng ~ 111*cos(lat) km
        delta_lat = radius_km / 111.0
        delta_lng = radius_km / (111.0 * math.cos(math.radians(lat)) if lat != 0 else 111.0)
        conditions.append(Event.lat >= lat - delta_lat)
        conditions.append(Event.lat <= lat + delta_lat)
        conditions.append(Event.lng >= lng - delta_lng)
        conditions.append(Event.lng <= lng + delta_lng)
    q = q.options(selectinload(Event.venue)).where(and_(*conditions)).order_by(Event.start_time.asc())
    result = await db.execute(q)
    return result.scalars().unique().all()


async def create(
    db: AsyncSession,
    *,
    organizer_id: int,
    venue_id: int,
    title: str,
    description: str | None,
    start_time: datetime | None,
    end_time: datetime | None,
    funding_goal_cents: int | None,
    funding_end_at: datetime | None,
    min_pledge_cents: int,
    registration_type: RegistrationType,
    max_capacity: int,
    max_reserved_spots_per_user: int = 0,
    common_discount_percent: int = 0,
    pledge_discount_percent: int = 0,
    lat: float | None = None,
    lng: float | None = None,
    allow_any_venue: bool = False,
    publish: bool = False,
    genre: str | None = None,
    community_rules: bool = False,
    posts_enabled: bool = True,
    refund_deadline_days: int | None = None,
    ticket_strategy_id: int | None = None,
    parking_info: str | None = None,
    transit_info: str | None = None,
    rideshare_info: str | None = None,
    accessibility_info: str | None = None,
    has_schedule: bool = False,
    link_funding_to_tiers: bool = False,
) -> Event:
    """Create event. At least one of funding_end_at or start_time must be provided."""
    from datetime import timedelta
    venue_result = await db.execute(select(Venue).where(Venue.id == venue_id))
    venue = venue_result.scalar_one_or_none()
    if not venue:
        raise NotFoundError("Venue", venue_id)
    if not allow_any_venue and venue.organizer_id != organizer_id:
        raise ForbiddenError("You can only create events at your own venues")
    if start_time is None and funding_end_at is None:
        raise ConflictError("At least one of event date or funding deadline must be set")
    if funding_end_at is not None and (funding_goal_cents is None or funding_goal_cents <= 0):
        raise ConflictError("Funding goal is required when a funding deadline is set")
    if start_time is not None and end_time is not None and end_time <= start_time:
        raise ConflictError("end_time must be after start_time")
    if start_time is not None and end_time is None:
        raise ConflictError("end_time is required when start_time is set")
    # Event start must be after funding deadline
    if start_time is not None and funding_end_at is not None:
        if start_time <= funding_end_at:
            raise ConflictError("Event start time must be after the funding deadline")
    # If no funding period, ticket strategy is required (event-only mode)
    if funding_end_at is None and ticket_strategy_id is None:
        raise ConflictError("Ticket strategy is required when no funding deadline is set")

    # Validate ticket strategy exists and belongs to organizer
    if ticket_strategy_id is not None:
        from app.models.ticket_strategy import TicketStrategy as TS
        ts_result = await db.execute(select(TS).where(TS.id == ticket_strategy_id))
        ts = ts_result.scalar_one_or_none()
        if not ts:
            raise NotFoundError("TicketStrategy", ticket_strategy_id)
        if not allow_any_venue and ts.organizer_id != organizer_id:
            raise ForbiddenError("You can only use your own ticket strategies")

    # ── Community rules (opt-in via toggle) ──
    if community_rules:
        from app.services import platform_settings as settings_svc
        if not await settings_svc.get_bool(db, "feature_community_rules_enabled"):
            raise ConflictError("Community rules are currently disabled by the platform.")
        max_duration = await settings_svc.get_int(db, "community_max_duration_days")
        if max_duration <= 0:
            max_duration = 14  # fallback
        max_ticket_cents = await settings_svc.get_int(db, "community_max_ticket_price_cents")
        if max_ticket_cents <= 0:
            max_ticket_cents = 5000  # $50 fallback

        # Duration check (funding period + event duration combined)
        if start_time is not None and end_time is not None and funding_end_at is not None:
            total_days = (end_time - funding_end_at).days if funding_end_at else (end_time - start_time).days
            if total_days > max_duration:
                raise ConflictError(
                    f"Community events are limited to {max_duration} days total. "
                    f"Your event spans {total_days} days."
                )
        elif start_time is not None and end_time is not None:
            event_days = (end_time - start_time).days
            if event_days > max_duration:
                raise ConflictError(
                    f"Community events are limited to {max_duration} days. "
                    f"Your event spans {event_days} days."
                )

        # Ticket price check (validate strategy tiers)
        if ticket_strategy_id is not None:
            from app.models.ticket_strategy import TicketStrategyTier as TST
            tier_q = select(TST).where(TST.strategy_id == ticket_strategy_id)
            tiers = list((await db.execute(tier_q)).scalars().all())
            for t in tiers:
                if t.price_cents > max_ticket_cents:
                    raise ConflictError(
                        f"Community events have a max ticket price of ${max_ticket_cents / 100:.2f}. "
                        f"Tier '{t.name}' is ${t.price_cents / 100:.2f}."
                    )

    # Refund deadline: auto-calculate as 20% of funding duration, and cap at that max
    if funding_end_at is not None:
        now = datetime.now(timezone.utc)
        funding_duration_days = max(1, (funding_end_at - now).days)
        max_refund_days = max(1, int(math.ceil(funding_duration_days * 0.2)))
        if refund_deadline_days is None:
            refund_deadline_days = max_refund_days
        elif refund_deadline_days > max_refund_days:
            raise ConflictError(
                f"Refund deadline cannot exceed {max_refund_days} days "
                f"(20% of {funding_duration_days}-day funding period)"
            )

    use_lat = lat if lat is not None else venue.lat
    use_lng = lng if lng is not None else venue.lng
    event = Event(
        organizer_id=organizer_id,
        venue_id=venue_id,
        title=title,
        description=description,
        start_time=start_time,
        end_time=end_time,
        lat=use_lat,
        lng=use_lng,
        funding_goal_cents=funding_goal_cents,
        funding_end_at=funding_end_at,
        min_pledge_cents=min_pledge_cents,
        registration_type=registration_type,
        max_capacity=max_capacity,
        max_reserved_spots_per_user=max_reserved_spots_per_user,
        common_discount_percent=common_discount_percent,
        pledge_discount_percent=pledge_discount_percent,
        genre=genre,
        community_rules=community_rules,
        posts_enabled=posts_enabled,
        refund_deadline_days=refund_deadline_days,
        ticket_strategy_id=ticket_strategy_id,
        parking_info=parking_info,
        transit_info=transit_info,
        rideshare_info=rideshare_info,
        accessibility_info=accessibility_info,
        has_schedule=has_schedule,
        link_funding_to_tiers=link_funding_to_tiers,
        status=EventStatus.approved if publish else EventStatus.draft,
    )
    db.add(event)
    await db.flush()
    await db.refresh(event)
    return event


async def update(
    db: AsyncSession,
    event: Event,
    *,
    title: str | None = None,
    description: str | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
    venue_id: int | None = None,
    funding_goal_cents: int | None = None,
    funding_end_at: datetime | None = None,
    min_pledge_cents: int | None = None,
    registration_type: RegistrationType | None = None,
    max_capacity: int | None = None,
    max_reserved_spots_per_user: int | None = None,
    common_discount_percent: int | None = None,
    pledge_discount_percent: int | None = None,
    genre: str | None = None,
    community_rules: bool | None = None,
    posts_enabled: bool | None = None,
    refund_deadline_days: int | None = None,
    ticket_strategy_id: int | None = None,
    parking_info: str | None = None,
    transit_info: str | None = None,
    rideshare_info: str | None = None,
    accessibility_info: str | None = None,
    has_schedule: bool | None = None,
    link_funding_to_tiers: bool | None = None,
) -> Event:
    """Update event fields (only provided ones). When switching closed→open, auto-approve waitlist up to capacity."""
    old_registration_type = event.registration_type
    if venue_id is not None and venue_id != event.venue_id:
        venue_result = await db.execute(select(Venue).where(Venue.id == venue_id))
        venue = venue_result.scalar_one_or_none()
        if not venue:
            raise NotFoundError("Venue", venue_id)
        event.venue_id = venue_id
        if venue.lat is not None:
            event.lat = venue.lat
        if venue.lng is not None:
            event.lng = venue.lng
    if title is not None:
        event.title = title
    if description is not None:
        event.description = description
    if start_time is not None:
        event.start_time = start_time
    if end_time is not None:
        event.end_time = end_time
    if funding_goal_cents is not None:
        event.funding_goal_cents = funding_goal_cents
    if funding_end_at is not None:
        event.funding_end_at = funding_end_at
    if min_pledge_cents is not None:
        event.min_pledge_cents = min_pledge_cents
    if registration_type is not None:
        event.registration_type = registration_type
    if max_capacity is not None:
        # Capacity floor guard: cannot reduce below tickets_sold + reserved_spots
        if max_capacity < event.max_capacity:
            from app.services import funding as funding_svc
            from app.models.ticket import TicketSale as _TS, TicketSaleStatus as _TSS
            total_reserved = await funding_svc.get_total_reserved_spots(db, event.id)
            tickets_sold_q = select(func.count()).where(
                _TS.event_id == event.id,
                _TS.status == _TSS.purchased,
            )
            tickets_sold = int((await db.execute(tickets_sold_q)).scalar_one())
            floor = tickets_sold + total_reserved
            if max_capacity < floor:
                raise ConflictError(
                    f"Cannot reduce capacity below {floor} "
                    f"({tickets_sold} tickets sold + {total_reserved} reserved spots)"
                )
        event.max_capacity = max_capacity
    if max_reserved_spots_per_user is not None:
        event.max_reserved_spots_per_user = max_reserved_spots_per_user
    if common_discount_percent is not None:
        event.common_discount_percent = common_discount_percent
    if pledge_discount_percent is not None:
        event.pledge_discount_percent = pledge_discount_percent
    if genre is not None:
        event.genre = genre
    if community_rules is not None:
        if event.status != EventStatus.draft:
            raise ConflictError("Community rules can only be changed while the event is in draft")
        event.community_rules = community_rules
    if posts_enabled is not None:
        event.posts_enabled = posts_enabled
    if refund_deadline_days is not None:
        # Enforce 20% cap of funding duration
        effective_funding_end = funding_end_at if funding_end_at is not None else event.funding_end_at
        if effective_funding_end is not None:
            now = datetime.now(timezone.utc)
            funding_duration_days = max(1, (effective_funding_end - now).days)
            max_refund_days = max(1, int(math.ceil(funding_duration_days * 0.2)))
            if refund_deadline_days > max_refund_days:
                raise ConflictError(
                    f"Refund deadline cannot exceed {max_refund_days} days "
                    f"(20% of {funding_duration_days}-day funding period)"
                )
        event.refund_deadline_days = refund_deadline_days
    if ticket_strategy_id is not None:
        from app.models.ticket import TicketTier, TicketSale
        strategy_changed = ticket_strategy_id != event.ticket_strategy_id
        # Check if tiers are missing (e.g. manually deleted) even for the same strategy
        tier_count = (await db.execute(
            select(func.count()).where(TicketTier.event_id == event.id)
        )).scalar_one()
        tiers_missing = int(tier_count) == 0

        if strategy_changed or tiers_missing:
            event.ticket_strategy_id = ticket_strategy_id
            # Re-copy tiers from strategy (delete old TicketTiers first, only if no sales)
            existing_sales = (await db.execute(
                select(TicketSale).where(TicketSale.event_id == event.id).limit(1)
            )).scalar_one_or_none()
            if existing_sales is None:
                existing_tiers = (await db.execute(
                    select(TicketTier).where(TicketTier.event_id == event.id)
                )).scalars().all()
                for t in existing_tiers:
                    await db.delete(t)
                await db.flush()
                from app.services import ticket_strategy as ts_service
                await ts_service.apply_strategy_to_event(db, strategy_id=ticket_strategy_id, event_id=event.id)
    # Parking & Transport (operational — never triggers re-approval)
    if parking_info is not None:
        event.parking_info = parking_info
    if transit_info is not None:
        event.transit_info = transit_info
    if rideshare_info is not None:
        event.rideshare_info = rideshare_info
    if accessibility_info is not None:
        event.accessibility_info = accessibility_info
    if has_schedule is not None:
        event.has_schedule = has_schedule
    if link_funding_to_tiers is not None:
        event.link_funding_to_tiers = link_funding_to_tiers
    # Validate dates if both are set
    if event.start_time is not None and event.end_time is not None and event.end_time <= event.start_time:
        raise ConflictError("end_time must be after start_time")
    if event.start_time is not None and event.funding_end_at is not None:
        if event.start_time <= event.funding_end_at:
            raise ConflictError("Event start time must be after the funding deadline")
    if event.funding_end_at is not None and (event.funding_goal_cents is None or event.funding_goal_cents <= 0):
        raise ConflictError("Funding goal is required when a funding deadline is set")
    await db.flush()
    if registration_type is not None and old_registration_type == RegistrationType.closed and registration_type == RegistrationType.open:
        from app.services import registration as registration_service
        await registration_service.auto_approve_waitlist_when_switching_to_open(
            db, event_id=event.id, event_max_capacity=event.max_capacity
        )
    await db.refresh(event)
    return event
