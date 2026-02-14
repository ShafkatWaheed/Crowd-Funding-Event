"""
Event CRUD, ownership checks, list filters (city, status, live, organizer, search, date, capacity, has_funding, has_tickets).
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
    from datetime import timedelta
    from app.services import platform_settings as settings_svc
    now = datetime.now(timezone.utc)
    changed = False

    def _tz(dt: datetime | None) -> datetime | None:
        if dt is None:
            return None
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)

    status = event.status

    # ── approved → check funding end / non-funded transitions ──
    if status == EventStatus.approved:
        funding_end = _tz(event.funding_end_at)
        if funding_end is not None and now >= funding_end:
            # Funding ended → always go to waiting_event_date (organizer must manually start selling)
            grace_days = await settings_svc.get_int(db, "event_date_grace_days")
            if event.event_date_deadline is None:
                event.event_date_deadline = funding_end + timedelta(days=grace_days)
            event.status = EventStatus.waiting_event_date
            changed = True
        elif funding_end is None and event.start_time is not None and event.ticket_strategy_id is not None:
            # Non-funded event with dates + ticket strategy → go straight to selling_tickets
            event.status = EventStatus.selling_tickets
            changed = True

    # ── waiting_event_date → check if deadline passed (organizer must manually start selling) ──
    if status == EventStatus.waiting_event_date:
        if event.event_date_deadline is not None and now >= _tz(event.event_date_deadline) and event.start_time is None:
            # Deadline passed, no date set → cancel and refund
            event.status = EventStatus.cancelled
            event.cancellation_reason = "Event date was not set within the required deadline. Pledges refunded."
            from app.services import funding as funding_service
            await funding_service.refund_all_pledges_for_event(db, event_id=event.id, guest_refund=False)
            changed = True

    # ── selling_tickets / approved → check if event started ──
    if event.status in (EventStatus.selling_tickets, EventStatus.approved):
        start = _tz(event.start_time)
        if start is not None and now >= start:
            event.status = EventStatus.live
            changed = True

    # ── live → check if event ended ──
    if event.status == EventStatus.live:
        end = _tz(event.end_time)
        if end is not None and now >= end:
            event.status = EventStatus.completed
            changed = True

    if changed:
        await db.flush()

    return event


def _event_can_edit(user: User, event: Event) -> bool:
    """Main organizer or admin (sync check, no co-organizers)."""
    return user.role.value == "admin" or event.organizer_id == user.id


async def user_can_edit_event(db: AsyncSession, event: Event, user: User) -> bool:
    """True if user is admin, main organizer, or co-organizer with 'full' permission."""
    if user.role.value == "admin" or event.organizer_id == user.id:
        return True
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event.id,
        EventOrganizer.user_id == user.id,
    )
    result = await db.execute(q)
    eo = result.scalar_one_or_none()
    return eo is not None and eo.permission == "full"


async def user_can_read_event_mgmt(db: AsyncSession, event: Event, user: User) -> bool:
    """True if user is admin, main organizer, or ANY co-organizer (read or full)."""
    if user.role.value == "admin" or event.organizer_id == user.id:
        return True
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event.id,
        EventOrganizer.user_id == user.id,
    )
    result = await db.execute(q)
    return result.scalar_one_or_none() is not None


def is_main_organizer(user: User, event: Event) -> bool:
    """True if user is the main organizer (owner) or admin. Only main organizer can add/remove co-organizers."""
    return user.role.value == "admin" or event.organizer_id == user.id


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
        q = q.options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
    if load_organizer:
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
) -> Sequence[Event]:
    """List events with optional filters. include_all_statuses=True skips the default hidden-status filter (for organizer/admin)."""
    conditions = []
    q = select(Event)
    need_venue_join = city is not None
    if need_venue_join:
        q = q.join(Event.venue)
        conditions.append(Venue.city == city)
    if search is not None and search.strip():
        search_term = f"%{search.strip()}%"
        # Text search on title and description (ILIKE; works on PostgreSQL and SQLite)
        conditions.append(
            or_(
                Event.title.ilike(search_term),
                (Event.description.isnot(None)) & (Event.description.ilike(search_term)),
            )
        )
    if status is not None:
        try:
            status_enum = EventStatus(status)
        except ValueError:
            return []
        conditions.append(Event.status == status_enum)
    elif not include_all_statuses and organizer_id is None:
        # Default: hide draft/pending/cancelled/waiting_event_date from public listing (customers)
        conditions.append(
            Event.status.notin_([
                EventStatus.draft, EventStatus.pending_approval,
                EventStatus.cancelled, EventStatus.waiting_event_date,
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
    if conditions:
        q = q.where(and_(*conditions))
    q = q.options(selectinload(Event.venue), selectinload(Event.ticket_strategy)).order_by(Event.start_time.asc())
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
) -> Sequence[Event]:
    """
    List events suitable for map markers: have lat/lng, not draft/pending/cancelled.
    Optional city (via venue), live filter, and lat/lng/radius_km (approximate bbox).
    """
    conditions = [
        Event.lat.isnot(None),
        Event.lng.isnot(None),
        Event.status.not_in([EventStatus.draft, EventStatus.pending_approval, EventStatus.cancelled]),
    ]
    q = select(Event)
    if city is not None:
        q = q.join(Event.venue)
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
    q = q.where(and_(*conditions)).order_by(Event.start_time.asc())
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
        common_discount_percent=common_discount_percent,
        pledge_discount_percent=pledge_discount_percent,
        genre=genre,
        community_rules=community_rules,
        posts_enabled=posts_enabled,
        refund_deadline_days=refund_deadline_days,
        ticket_strategy_id=ticket_strategy_id,
        status=EventStatus.approved if publish else EventStatus.draft,
    )
    db.add(event)
    await db.flush()

    # If strategy linked, copy tiers into the event's TicketTier rows
    if ticket_strategy_id is not None:
        from app.services import ticket_strategy as ts_service
        await ts_service.apply_strategy_to_event(db, strategy_id=ticket_strategy_id, event_id=event.id)

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
    common_discount_percent: int | None = None,
    pledge_discount_percent: int | None = None,
    genre: str | None = None,
    community_rules: bool | None = None,
    posts_enabled: bool | None = None,
    refund_deadline_days: int | None = None,
    ticket_strategy_id: int | None = None,
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
        event.max_capacity = max_capacity
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


async def _check_cancel_threshold(db: AsyncSession, event: Event, user: User, reason: str | None = None) -> bool:
    """
    If event is >= cancel_approval_threshold_percent funded, block direct cancellation
    and create a pending cancellation request instead. Returns True if blocked.
    Admins bypass this check.
    """
    from app.models.user import UserRole
    if user.role == UserRole.admin:
        return False  # admins can cancel directly

    if event.funding_goal_cents and event.funding_goal_cents > 0:
        from app.services import funding as funding_service
        from app.services import platform_settings as settings_svc
        summary = await funding_service.get_summary(db, event_id=event.id)
        total_pledged = summary["total_pledged_cents"]
        threshold = await settings_svc.get_int(db, "cancel_approval_threshold_percent")
        pledge_pct = (total_pledged * 100) // event.funding_goal_cents if event.funding_goal_cents > 0 else 0
        if pledge_pct >= threshold:
            from datetime import datetime, timezone
            event.pending_cancellation = {
                "reason": reason or "Organizer requested cancellation",
                "requested_at": datetime.now(timezone.utc).isoformat(),
                "requested_by": user.id,
                "pledge_percent": pledge_pct,
            }
            await db.flush()
            await db.refresh(event)
            return True
    return False


async def cancel_event(db: AsyncSession, event: Event, user: User, *, reason: str | None = None) -> Event:
    """
    Cancel the event. Rules:
    - Not allowed if already cancelled or completed.
    - selling_tickets: only admin can cancel directly; organizers create a
      pending cancellation request that admin must approve.
    - Other statuses: organizer can cancel directly (subject to funding threshold check).
    - If >=80% funded (any status), routes to admin approval queue.
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot cancel this event")
    if event.status == EventStatus.cancelled:
        raise ConflictError("Event is already cancelled")
    if event.status in (EventStatus.completed,):
        raise ConflictError("Cannot cancel a completed event")

    from app.models.user import UserRole

    # selling_tickets: non-admin must request admin approval
    if event.status == EventStatus.selling_tickets and user.role != UserRole.admin:
        from datetime import datetime, timezone
        event.pending_cancellation = {
            "reason": reason or "Organizer requested cancellation",
            "requested_at": datetime.now(timezone.utc).isoformat(),
            "requested_by": user.id,
            "status": event.status.value,
        }
        await db.flush()
        await db.refresh(event)
        raise ConflictError(
            "Cancellation request has been sent to admin for approval."
        )

    # Check if cancel needs admin approval (high pledge %)
    blocked = await _check_cancel_threshold(db, event, user, reason)
    if blocked:
        raise ConflictError(
            f"This event is {event.pending_cancellation['pledge_percent']}% funded. "
            "Your cancellation request has been sent to admin for approval."
        )

    event.status = EventStatus.cancelled
    event.cancellation_reason = reason
    from app.services import funding as funding_service
    await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
    await db.flush()
    await db.refresh(event)
    return event


async def reactivate_event(db: AsyncSession, event: Event, user: User) -> Event:
    """
    Move a cancelled event back to draft so the organizer can edit and republish it.
    Only allowed when status is cancelled.
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot reactivate this event")
    if event.status != EventStatus.cancelled:
        raise ConflictError("Only cancelled events can be moved back to draft")
    event.status = EventStatus.draft
    await db.flush()
    await db.refresh(event)
    return event


async def extend_funding(
    db: AsyncSession,
    event: Event,
    user: User,
    *,
    new_funding_end_at: datetime | None = None,
    new_funding_goal_cents: int | None = None,
) -> Event:
    """
    Request to extend funding period with a new deadline and/or goal.
    Admin can apply directly; organizer request goes to pending approval.
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot update this event")
    if event.status in (EventStatus.cancelled, EventStatus.completed):
        raise ConflictError(f"Cannot extend a {event.status.value} event")
    if new_funding_end_at is None and new_funding_goal_cents is None:
        raise ConflictError("At least one of funding_end_at or funding_goal_cents is required")
    if new_funding_goal_cents is not None and new_funding_goal_cents <= 0:
        raise ConflictError("Funding goal must be positive")

    # Admin: apply immediately
    if user.role.value == "admin":
        return await _apply_funding_extension(db, event, new_funding_end_at, new_funding_goal_cents)

    # Organizer: store as pending extension requiring admin approval
    pending: dict = {}
    if new_funding_end_at is not None:
        pending["funding_end_at"] = new_funding_end_at.isoformat()
    if new_funding_goal_cents is not None:
        pending["funding_goal_cents"] = new_funding_goal_cents
    event.pending_extension = pending
    await db.flush()
    return event


async def set_event_date(
    db: AsyncSession,
    event: Event,
    user: User,
    *,
    new_start_time: datetime,
    new_end_time: datetime,
) -> Event:
    """
    Set or update event start/end time.
    Applies directly (no admin approval). Does NOT auto-transition — organizer must
    manually start selling tickets via the dedicated action.
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot update this event")
    if event.status in (EventStatus.cancelled, EventStatus.completed):
        raise ConflictError(f"Cannot set date on a {event.status.value} event")
    if new_end_time <= new_start_time:
        raise ConflictError("end_time must be after start_time")
    # Start must be after funding deadline (if one exists)
    if event.funding_end_at is not None:
        funding_end = event.funding_end_at if event.funding_end_at.tzinfo else event.funding_end_at.replace(tzinfo=timezone.utc)
        if new_start_time <= funding_end:
            raise ConflictError("Event start time must be after the funding deadline")

    event.start_time = new_start_time
    event.end_time = new_end_time

    await db.flush()
    return event


async def start_selling_tickets(
    db: AsyncSession,
    event: Event,
    user: User,
) -> Event:
    """
    Manually transition event to selling_tickets.
    Requires: event date set, ticket strategy set, event in waiting_event_date or approved (with funding ended).
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot update this event")
    if event.status not in (EventStatus.waiting_event_date, EventStatus.approved):
        raise ConflictError(f"Cannot start selling tickets from {event.status.value} status")
    if event.start_time is None or event.end_time is None:
        raise ConflictError("Event start and end times must be set before selling tickets")
    if event.ticket_strategy_id is None:
        raise ConflictError("A ticket strategy is required before selling tickets")
    # If approved with active funding, don't allow early ticket sales
    if event.status == EventStatus.approved and event.funding_end_at is not None:
        now = datetime.now(timezone.utc)
        funding_end = event.funding_end_at if event.funding_end_at.tzinfo else event.funding_end_at.replace(tzinfo=timezone.utc)
        if now < funding_end:
            raise ConflictError("Cannot start selling tickets while funding is still active")

    event.status = EventStatus.selling_tickets
    await db.flush()
    return event


async def approve_extension(db: AsyncSession, event: Event, admin: User) -> Event:
    """Admin approves a pending funding extension."""
    if admin.role.value != "admin":
        raise ForbiddenError("Only admin can approve extensions")
    ext = event.pending_extension
    if not ext:
        raise ConflictError("No pending extension to approve")
    funding_end = datetime.fromisoformat(ext["funding_end_at"]) if ext.get("funding_end_at") else None
    goal_cents = ext.get("funding_goal_cents")
    event.pending_extension = None
    return await _apply_funding_extension(db, event, funding_end, goal_cents)


async def reject_extension(db: AsyncSession, event: Event, admin: User) -> Event:
    """Admin rejects a pending funding extension."""
    if admin.role.value != "admin":
        raise ForbiddenError("Only admin can reject extensions")
    if not event.pending_extension:
        raise ConflictError("No pending extension to reject")
    event.pending_extension = None
    await db.flush()
    return event


async def _apply_funding_extension(
    db: AsyncSession,
    event: Event,
    new_funding_end_at: datetime | None,
    new_funding_goal_cents: int | None,
) -> Event:
    """Apply funding extension directly (new deadline and/or goal)."""
    if new_funding_end_at is not None:
        event.funding_end_at = new_funding_end_at
    if new_funding_goal_cents is not None:
        event.funding_goal_cents = new_funding_goal_cents
    # If event was in waiting_event_date with new funding deadline, move back to approved (funding re-opens)
    if event.status == EventStatus.waiting_event_date and new_funding_end_at is not None:
        event.status = EventStatus.approved
    await db.flush()
    return event


async def _purge_event_children(db: AsyncSession, event_id: int) -> None:
    """Delete all child records for an event before hard-deleting the event itself."""
    from sqlalchemy import delete as sa_delete
    from app.models.escrow import EscrowRelease, FundEscrow
    from app.models.discount_strategy import CustomerDiscountClaim, EventDiscountStrategyLink

    # Escrow releases (child of escrow)
    escrow_ids_q = select(FundEscrow.id).where(FundEscrow.event_id == event_id)
    await db.execute(sa_delete(EscrowRelease).where(EscrowRelease.escrow_id.in_(escrow_ids_q)))
    await db.execute(sa_delete(FundEscrow).where(FundEscrow.event_id == event_id))

    # Discount claims (child of strategy links)
    link_ids_q = select(EventDiscountStrategyLink.id).where(EventDiscountStrategyLink.event_id == event_id)
    await db.execute(sa_delete(CustomerDiscountClaim).where(CustomerDiscountClaim.link_id.in_(link_ids_q)))
    await db.execute(sa_delete(EventDiscountStrategyLink).where(EventDiscountStrategyLink.event_id == event_id))

    # Ticket sales (child of both event and ticket_tier)
    await db.execute(sa_delete(TicketSale).where(TicketSale.event_id == event_id))
    await db.execute(sa_delete(TicketTier).where(TicketTier.event_id == event_id))
    await db.execute(sa_delete(UserEventDiscount).where(UserEventDiscount.event_id == event_id))

    # Fundings, registrations
    await db.execute(sa_delete(Funding).where(Funding.event_id == event_id))
    await db.execute(sa_delete(Registration).where(Registration.event_id == event_id))

    # Other children (organizers, posts, images, reactions, discounts) handled by ORM cascade
    # but do explicit deletes for safety
    from app.models.event import EventOrganizer, EventReaction, EventDiscount
    from app.models.post import EventPost
    from app.models.image import EventImage
    await db.execute(sa_delete(EventOrganizer).where(EventOrganizer.event_id == event_id))
    await db.execute(sa_delete(EventReaction).where(EventReaction.event_id == event_id))
    await db.execute(sa_delete(EventDiscount).where(EventDiscount.event_id == event_id))
    await db.execute(sa_delete(EventPost).where(EventPost.event_id == event_id))
    await db.execute(sa_delete(EventImage).where(EventImage.event_id == event_id))

    await db.flush()


async def delete_or_cancel(db: AsyncSession, event: Event, user: User) -> None:
    """
    Delete event (hard) if draft or cancelled; otherwise set status to cancelled (soft).
    If >=80% funded, routes to admin approval queue instead.
    Raises ForbiddenError if user cannot edit.
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot delete this event")
    if event.status in (EventStatus.draft, EventStatus.cancelled):
        await _purge_event_children(db, event.id)
        await db.delete(event)
        await db.flush()
    elif event.status == EventStatus.completed:
        raise ConflictError("Cannot delete a completed event (clone it instead)")
    else:
        # Check if cancel needs admin approval (high pledge %)
        blocked = await _check_cancel_threshold(db, event, user, "Organizer requested deletion")
        if blocked:
            raise ConflictError(
                f"This event is {event.pending_cancellation['pledge_percent']}% funded. "
                "Your cancellation request has been sent to admin for approval."
            )
        event.status = EventStatus.cancelled
        from app.services import funding as funding_service
        await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
        await db.flush()


async def get_my_registered_events(db: AsyncSession, *, user_id: int) -> Sequence[Event]:
    """Events the user is registered to (any registration status). Useful for 'My Events'."""
    q = (
        select(Event)
        .join(Registration, Registration.event_id == Event.id)
        .where(
            Registration.user_id == user_id,
            Registration.status.in_([RegistrationStatus.registered, RegistrationStatus.waitlist]),
        )
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .order_by(Event.created_at.desc())
    )
    result = await db.execute(q)
    return result.scalars().unique().all()


async def get_trending_events(db: AsyncSession, *, limit: int = 10) -> Sequence[Event]:
    """Events ordered by registration_count DESC. Public-visible statuses."""
    q = (
        select(Event)
        .where(Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live]))
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .order_by(Event.registration_count.desc(), Event.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(q)
    return result.scalars().unique().all()


async def get_coming_soon_events(db: AsyncSession, *, limit: int = 10) -> Sequence[Event]:
    """Approved events starting in the future, ordered by start_time ASC."""
    now = datetime.now(timezone.utc)
    q = (
        select(Event)
        .where(
            Event.status.in_([EventStatus.approved, EventStatus.selling_tickets]),
            Event.start_time.isnot(None),
            Event.start_time > now,
        )
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .order_by(Event.start_time.asc())
        .limit(limit)
    )
    result = await db.execute(q)
    return result.scalars().unique().all()


async def get_popular_events(db: AsyncSession, *, limit: int = 10) -> Sequence[Event]:
    """Events with most pledged amount. Public-visible statuses."""
    from app.models.funding import Funding, FundingStatus
    q = (
        select(Event, func.coalesce(func.sum(Funding.amount_cents), 0).label("total_pledged"))
        .outerjoin(Funding, and_(Funding.event_id == Event.id, Funding.status == FundingStatus.pledged))
        .where(Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live]))
        .group_by(Event.id)
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .order_by(func.coalesce(func.sum(Funding.amount_cents), 0).desc())
        .limit(limit)
    )
    result = await db.execute(q)
    return [row[0] for row in result.unique().all()]


async def clone_event(db: AsyncSession, event: Event, user: User) -> Event:
    """
    Clone a completed event into a new draft. Copies all params except
    start_time, end_time, funding_end_at (those must be set fresh).
    """
    if event.status != EventStatus.completed:
        raise ConflictError("Only completed events can be cloned")
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot clone this event")
    new_event = Event(
        organizer_id=event.organizer_id,
        venue_id=event.venue_id,
        title=f"{event.title} (Copy)",
        description=event.description,
        start_time=None,
        end_time=None,
        lat=event.lat,
        lng=event.lng,
        funding_goal_cents=event.funding_goal_cents,
        funding_end_at=None,
        min_pledge_cents=event.min_pledge_cents,
        registration_type=event.registration_type,
        max_capacity=event.max_capacity,
        common_discount_percent=event.common_discount_percent,
        pledge_discount_percent=event.pledge_discount_percent,
        genre=event.genre,
        community_rules=event.community_rules,
        posts_enabled=event.posts_enabled,
        refund_deadline_days=None,
        ticket_strategy_id=event.ticket_strategy_id,
        status=EventStatus.draft,
    )
    db.add(new_event)
    await db.flush()
    await db.refresh(new_event)
    return new_event


# ----- Event co-organizers (main organizer only can add/remove) -----


async def list_event_organizers(db: AsyncSession, *, event_id: int) -> tuple[User, list[EventOrganizer]]:
    """
    Return (main_organizer, [co_organizers]) for the event.
    Main organizer is event.organizer; co-organizers are from event_organizers table.
    """
    event = await get_by_id(db, event_id, load_organizer=True)
    if not event:
        raise NotFoundError("Event", event_id)
    main = event.organizer
    q = (
        select(EventOrganizer)
        .where(EventOrganizer.event_id == event_id)
        .options(selectinload(EventOrganizer.user))
        .order_by(EventOrganizer.created_at.asc())
    )
    result = await db.execute(q)
    co_organizers = list(result.scalars().unique().all())
    return main, co_organizers


async def add_event_organizer(
    db: AsyncSession, *, event_id: int, user_id: int, added_by: User, permission: str = "read"
) -> EventOrganizer:
    """Main organizer adds a co-organizer. User must have role organizer."""
    event = await get_or_404(db, event_id)
    if not is_main_organizer(added_by, event):
        raise ForbiddenError("Only the main organizer can add co-organizers")
    if user_id == event.organizer_id:
        raise ConflictError("User is already the main organizer")
    if permission not in ("read", "full"):
        raise ConflictError("Permission must be 'read' or 'full'")
    # Load user to check role
    target = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not target:
        raise NotFoundError("User", user_id)
    if target.role.value != "organizer":
        raise ConflictError("Only users with organizer role can be added as co-organizers")
    existing = (
        await db.execute(
            select(EventOrganizer).where(
                EventOrganizer.event_id == event_id,
                EventOrganizer.user_id == user_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        raise ConflictError("User is already a co-organizer for this event")
    eo = EventOrganizer(event_id=event_id, user_id=user_id, permission=permission)
    db.add(eo)
    await db.flush()
    await db.refresh(eo)
    return eo


async def remove_event_organizer(db: AsyncSession, *, event_id: int, user_id: int, removed_by: User) -> None:
    """Main organizer removes a co-organizer. Cannot remove main organizer."""
    event = await get_or_404(db, event_id)
    if not is_main_organizer(removed_by, event):
        raise ForbiddenError("Only the main organizer can remove co-organizers")
    if user_id == event.organizer_id:
        raise ConflictError("Cannot remove the main organizer")
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event_id,
        EventOrganizer.user_id == user_id,
    )
    result = await db.execute(q)
    eo = result.scalar_one_or_none()
    if not eo:
        raise NotFoundError("Co-organizer", user_id)
    await db.delete(eo)
    await db.flush()


# ═══════════════════════════════════════════
# Event Discounts
# ═══════════════════════════════════════════


async def list_event_discounts(db: AsyncSession, *, event_id: int) -> list[EventDiscount]:
    q = select(EventDiscount).where(EventDiscount.event_id == event_id).order_by(EventDiscount.id)
    return list((await db.execute(q)).scalars().all())


async def create_event_discount(
    db: AsyncSession, *, event_id: int, user: User,
    name: str, discount_type: str, value: int, target: str = "all",
) -> EventDiscount:
    event = await get_or_404(db, event_id)
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("Only event organizer or admin can manage discounts")
    if discount_type not in ("pledge_percent", "ticket_percent"):
        raise ConflictError("discount_type must be 'pledge_percent' or 'ticket_percent'")
    if target not in ("all", "pledgers", "non_pledgers"):
        raise ConflictError("target must be 'all', 'pledgers', or 'non_pledgers'")
    if discount_type == "pledge_percent" and target == "non_pledgers":
        raise ConflictError("'% of Pledge' discount cannot target non-pledgers")
    if not (0 < value <= 100):
        raise ConflictError("Percent value must be 1-100")
    disc = EventDiscount(
        event_id=event_id, name=name, discount_type=discount_type, value=value, target=target,
    )
    db.add(disc)
    await db.flush()
    await db.refresh(disc)
    return disc


async def delete_event_discount(db: AsyncSession, *, event_id: int, discount_id: int, user: User) -> None:
    event = await get_or_404(db, event_id)
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("Only event organizer or admin can manage discounts")
    q = select(EventDiscount).where(EventDiscount.id == discount_id, EventDiscount.event_id == event_id)
    disc = (await db.execute(q)).scalar_one_or_none()
    if not disc:
        raise NotFoundError("Discount", discount_id)
    await db.delete(disc)
    await db.flush()


# ═══════════════════════════════════════════
# Customer discounts (what discount a specific customer gets)
# ═══════════════════════════════════════════


async def compute_event_discounts_for_user(
    db: AsyncSession, *, event_id: int, user_id: int,
) -> list[dict]:
    """Return all applicable discount rules for a user (inline + auto-applied linked strategies + claimed strategies)."""
    from app.models.discount_strategy import CustomerDiscountClaim
    from sqlalchemy.orm import selectinload as _sload

    event = await get_or_404(db, event_id)
    inline_discounts = await list_event_discounts(db, event_id=event_id)

    # Linked strategies with auto_apply info
    link_q = (
        select(EventDiscountStrategyLink)
        .options(_sload(EventDiscountStrategyLink.strategy))
        .where(EventDiscountStrategyLink.event_id == event_id)
    )
    links = list((await db.execute(link_q)).scalars().all())

    # Claims by this user
    claim_q = select(CustomerDiscountClaim.link_id).where(
        CustomerDiscountClaim.user_id == user_id,
        CustomerDiscountClaim.link_id.in_([l.id for l in links]) if links else False,
    )
    claimed_ids = set((await db.execute(claim_q)).scalars().all()) if links else set()

    # Check if user has pledged
    pledge_q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.user_id == user_id,
        Funding.status == FundingStatus.pledged,
    )
    total_pledged = int((await db.execute(pledge_q)).scalar_one())
    has_pledged = total_pledged > 0

    results = []
    # Inline EventDiscount rules
    for d in inline_discounts:
        if d.target == "pledgers" and not has_pledged:
            continue
        if d.target == "non_pledgers" and has_pledged:
            continue
        results.append({
            "id": d.id,
            "name": d.name,
            "discount_type": d.discount_type,
            "value": d.value,
            "target": d.target,
            "total_pledged_cents": total_pledged if d.discount_type == "pledge_percent" else 0,
        })
    # Linked DiscountStrategy rules — only auto-apply or claimed
    for link in links:
        if not link.auto_apply and link.id not in claimed_ids:
            continue
        s = link.strategy
        if s.target == "pledgers" and not has_pledged:
            continue
        if s.target == "non_pledgers" and has_pledged:
            continue
        results.append({
            "id": s.id,
            "name": s.name,
            "discount_type": s.discount_type,
            "value": s.value,
            "target": s.target,
            "total_pledged_cents": total_pledged if s.discount_type == "pledge_percent" else 0,
            "source": "strategy",
            "auto_apply": link.auto_apply,
            "claimed": link.id in claimed_ids,
        })
    return results


# ═══════════════════════════════════════════
# Organizer–Customer History
# ═══════════════════════════════════════════


async def record_customer_attendance(
    db: AsyncSession, *, organizer_id: int, customer_id: int, event_id: int, scanned_at: datetime,
) -> None:
    """Record that a customer attended an organizer's event. Idempotent (ignores duplicates)."""
    existing = (
        await db.execute(
            select(OrganizerCustomerHistory).where(
                OrganizerCustomerHistory.organizer_id == organizer_id,
                OrganizerCustomerHistory.customer_id == customer_id,
                OrganizerCustomerHistory.event_id == event_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        return  # already recorded
    h = OrganizerCustomerHistory(
        organizer_id=organizer_id, customer_id=customer_id,
        event_id=event_id, scanned_at=scanned_at,
    )
    db.add(h)
    await db.flush()


async def list_organizer_customers(db: AsyncSession, *, organizer_id: int) -> list[dict]:
    """List all unique customers who attended events organized by this organizer, with event count."""
    q = (
        select(
            OrganizerCustomerHistory.customer_id,
            User.display_name,
            func.count(OrganizerCustomerHistory.id).label("events_attended"),
            func.max(OrganizerCustomerHistory.scanned_at).label("last_attended"),
        )
        .join(User, User.id == OrganizerCustomerHistory.customer_id)
        .where(OrganizerCustomerHistory.organizer_id == organizer_id)
        .group_by(OrganizerCustomerHistory.customer_id, User.display_name)
        .order_by(func.count(OrganizerCustomerHistory.id).desc())
    )
    rows = (await db.execute(q)).all()
    return [
        {
            "customer_id": r.customer_id,
            "customer_name": r.display_name,
            "events_attended": r.events_attended,
            "last_attended": r.last_attended.isoformat() if r.last_attended else None,
        }
        for r in rows
    ]


async def get_organizer_trust_score(db: AsyncSession, *, organizer_id: int) -> dict:
    """
    Compute trust score for an organizer.

    Score = completed events / total published events (approved or beyond).
    Published means any event that has left the draft state at some point
    (approved, selling_tickets, waiting_event_date, live, completed, cancelled).

    Returns dict with score (0.0–1.0), completed count, published count,
    and a label (New / Low / Good / Excellent).
    """
    published_statuses = [
        EventStatus.approved,
        EventStatus.pending_approval,
        EventStatus.selling_tickets,
        EventStatus.waiting_event_date,
        EventStatus.live,
        EventStatus.completed,
        EventStatus.cancelled,
    ]

    total_published = (await db.execute(
        select(func.count()).where(
            Event.organizer_id == organizer_id,
            Event.status.in_(published_statuses),
        )
    )).scalar_one()

    total_completed = (await db.execute(
        select(func.count()).where(
            Event.organizer_id == organizer_id,
            Event.status == EventStatus.completed,
        )
    )).scalar_one()

    if total_published == 0:
        score = 0.0
        label = "New"
    else:
        score = round(total_completed / total_published, 2)
        if score >= 0.8:
            label = "Excellent"
        elif score >= 0.5:
            label = "Good"
        elif score >= 0.2:
            label = "Fair"
        else:
            label = "New" if total_completed == 0 else "Low"

    return {
        "organizer_id": organizer_id,
        "trust_score": score,
        "completed_events": int(total_completed),
        "published_events": int(total_published),
        "label": label,
    }
