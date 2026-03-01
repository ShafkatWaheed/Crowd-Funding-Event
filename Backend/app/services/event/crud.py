"""
Event CRUD: auto_transition_status, get_by_id, get_or_404, publish_event, list_events, list_events_for_map, create, update.
"""
import base64
import json
import math
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import func, nulls_last, select, and_, or_, exists
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.logger import get_logger
from app.models.event import Event, EventOrganizer, EventDiscount, OrganizerCustomerHistory, EventStatus, RegistrationType
from app.models.discount_strategy import DiscountStrategy, EventDiscountStrategyLink
from app.models.registration import Registration, RegistrationStatus
from app.models.venue import Venue
from app.models.user import User
from app.models.ticket import TicketTier, TicketSale, UserEventDiscount
from app.models.funding import Funding, FundingStatus
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError

from app.services.event.permissions import user_can_edit_event

log = get_logger(__name__)


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

    # Event must have a funding goal or at least one ticket tier
    has_funding = event.funding_goal_cents is not None and event.funding_goal_cents > 0
    tier_count = (await db.execute(
        select(func.count()).select_from(TicketTier).where(TicketTier.event_id == event.id)
    )).scalar_one()
    if not has_funding and tier_count == 0:
        raise ConflictError("Event must have a funding goal or at least one ticket tier before publishing")

    event.status = EventStatus.approved
    await db.flush()
    await db.refresh(event)
    return event


def _encode_cursor(start_time: datetime | None, event_id: int) -> str:
    """Encode keyset cursor as base64url JSON."""
    t = start_time.isoformat() if start_time else None
    payload = {"t": t, "i": event_id}
    return base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")


def _decode_cursor(cursor: str) -> tuple[datetime | None, int] | None:
    """Decode keyset cursor. Returns (start_time, event_id) or None if invalid."""
    try:
        pad = 4 - len(cursor) % 4
        if pad != 4:
            cursor += "=" * pad
        payload = json.loads(base64.urlsafe_b64decode(cursor).decode())
        t = payload.get("t")
        i = int(payload["i"])
        start_time = datetime.fromisoformat(t.replace("Z", "+00:00")) if t else None
        return (start_time, i)
    except (ValueError, KeyError, TypeError):
        return None


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
    offset: int | None = None,
    limit: int | None = None,
    cursor: str | None = None,
) -> tuple[Sequence[Event], str | None]:
    """List events with optional filters. Returns (events, next_cursor)."""
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
            return ([], None)
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
            return ([], None)
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

    use_keyset = cursor is not None and limit is not None
    if use_keyset:
        decoded = _decode_cursor(cursor)
        if decoded:
            cursor_start_time, cursor_id = decoded
            if cursor_start_time is not None:
                keyset = or_(
                    Event.start_time > cursor_start_time,
                    (Event.start_time == cursor_start_time) & (Event.id > cursor_id),
                    Event.start_time.is_(None),
                )
            else:
                keyset = or_(
                    Event.start_time.isnot(None),
                    (Event.start_time.is_(None) & (Event.id > cursor_id)),
                )
            q = q.where(keyset)
        else:
            use_keyset = False

    q = q.options(
        selectinload(Event.venue),
        selectinload(Event.ticket_strategy),
        selectinload(Event.organizer),
    ).order_by(nulls_last(Event.start_time.asc()), Event.id.asc())
    if not use_keyset and offset is not None and offset > 0:
        q = q.offset(offset)
    if limit is not None:
        q = q.limit(limit + 1 if use_keyset else limit)
    result = await db.execute(q)
    rows = result.scalars().unique().all()

    next_cursor = None
    if use_keyset and limit is not None and len(rows) > limit:
        rows = list(rows)[:limit]
        last = rows[-1]
        next_cursor = _encode_cursor(last.start_time, last.id)
    elif not use_keyset:
        next_cursor = None

    return (rows, next_cursor)


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
    sponsorship_only: bool = False,
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
    if sponsorship_only:
        from app.models.sponsor import SponsorshipCategory
        conditions.append(exists(
            select(SponsorshipCategory.id).where(
                SponsorshipCategory.event_id == Event.id,
                SponsorshipCategory.is_template == False,
            )
        ))
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
    waitlist_max_size: int | None = None,
    waitlist_auto_approve: bool = True,
    event_max_images: int | None = None,
    max_posts_per_day: int | None = None,
    max_co_organizers: int | None = None,
    refund_deadline_percent: int | None = None,
) -> Event:
    """Create event. At least one of funding_end_at or start_time must be provided."""
    from datetime import timedelta
    from app.services import platform_settings as settings_svc

    max_events = await settings_svc.get_int(db, "max_events_per_organizer")
    if max_events > 0:
        active_count = (await db.execute(
            select(func.count()).select_from(Event).where(
                Event.organizer_id == organizer_id,
                Event.status.notin_(["cancelled", "completed"]),
            )
        )).scalar_one()
        if active_count >= max_events:
            raise ConflictError(f"You can have at most {max_events} active events")

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

    refund_pct_max = await settings_svc.get_int(db, "refund_deadline_percent_max")
    if refund_pct_max <= 0:
        refund_pct_max = 50
    refund_pct = refund_pct_max / 100

    if funding_end_at is not None:
        now = datetime.now(timezone.utc)
        funding_duration_days = max(1, (funding_end_at - now).days)
        max_refund_days = max(1, int(math.ceil(funding_duration_days * refund_pct)))
        if refund_deadline_days is None:
            refund_deadline_days = max_refund_days
        elif refund_deadline_days > max_refund_days:
            raise ConflictError(
                f"Refund deadline cannot exceed {max_refund_days} days "
                f"({refund_pct_max}% of {funding_duration_days}-day funding period)"
            )

    # Clamp per-event policy fields to platform ceilings
    if waitlist_max_size is not None:
        ceil = await settings_svc.get_int(db, "waitlist_max_size_limit")
        waitlist_max_size = min(waitlist_max_size, ceil) if ceil > 0 else waitlist_max_size
    if event_max_images is not None:
        ceil = await settings_svc.get_int(db, "event_max_images_limit")
        event_max_images = min(event_max_images, ceil) if ceil > 0 else event_max_images
    if max_posts_per_day is not None:
        ceil = await settings_svc.get_int(db, "max_posts_per_event_limit")
        max_posts_per_day = min(max_posts_per_day, ceil) if ceil > 0 else max_posts_per_day
    if max_co_organizers is not None:
        ceil = await settings_svc.get_int(db, "max_co_organizers_limit")
        max_co_organizers = min(max_co_organizers, ceil) if ceil > 0 else max_co_organizers
    if refund_deadline_percent is not None:
        pct_min = await settings_svc.get_int(db, "refund_deadline_percent_min")
        pct_max_val = await settings_svc.get_int(db, "refund_deadline_percent_max")
        refund_deadline_percent = max(pct_min, min(refund_deadline_percent, pct_max_val))

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
        waitlist_max_size=waitlist_max_size,
        waitlist_auto_approve=waitlist_auto_approve,
        event_max_images=event_max_images,
        max_posts_per_day=max_posts_per_day,
        max_co_organizers=max_co_organizers,
        refund_deadline_percent=refund_deadline_percent,
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
    waitlist_max_size: int | None = None,
    waitlist_auto_approve: bool | None = None,
    event_max_images: int | None = None,
    max_posts_per_day: int | None = None,
    max_co_organizers: int | None = None,
    refund_deadline_percent: int | None = None,
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
        from app.services import platform_settings as settings_svc
        upd_pct_max = await settings_svc.get_int(db, "refund_deadline_percent_max")
        if upd_pct_max <= 0:
            upd_pct_max = 50
        upd_pct = upd_pct_max / 100
        effective_funding_end = funding_end_at if funding_end_at is not None else event.funding_end_at
        if effective_funding_end is not None:
            now = datetime.now(timezone.utc)
            funding_duration_days = max(1, (effective_funding_end - now).days)
            max_refund_days = max(1, int(math.ceil(funding_duration_days * upd_pct)))
            if refund_deadline_days > max_refund_days:
                raise ConflictError(
                    f"Refund deadline cannot exceed {max_refund_days} days "
                    f"({upd_pct_max}% of {funding_duration_days}-day funding period)"
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
    # Per-event policy updates with ceiling clamping
    if any(v is not None for v in [waitlist_max_size, waitlist_auto_approve, event_max_images, max_posts_per_day, max_co_organizers, refund_deadline_percent]):
        from app.services import platform_settings as _ps
        if waitlist_max_size is not None:
            ceil = await _ps.get_int(db, "waitlist_max_size_limit")
            event.waitlist_max_size = min(waitlist_max_size, ceil) if ceil > 0 else waitlist_max_size
        if waitlist_auto_approve is not None:
            event.waitlist_auto_approve = waitlist_auto_approve
        if event_max_images is not None:
            ceil = await _ps.get_int(db, "event_max_images_limit")
            event.event_max_images = min(event_max_images, ceil) if ceil > 0 else event_max_images
        if max_posts_per_day is not None:
            ceil = await _ps.get_int(db, "max_posts_per_event_limit")
            event.max_posts_per_day = min(max_posts_per_day, ceil) if ceil > 0 else max_posts_per_day
        if max_co_organizers is not None:
            ceil = await _ps.get_int(db, "max_co_organizers_limit")
            event.max_co_organizers = min(max_co_organizers, ceil) if ceil > 0 else max_co_organizers
        if refund_deadline_percent is not None:
            pct_min = await _ps.get_int(db, "refund_deadline_percent_min")
            pct_max_val = await _ps.get_int(db, "refund_deadline_percent_max")
            event.refund_deadline_percent = max(pct_min, min(refund_deadline_percent, pct_max_val))
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


async def get_effective_policy(db: AsyncSession, event: "Event") -> dict:
    """Resolve per-event settings: admin_override > organizer value > global default."""
    from app.services import platform_settings as s

    def _resolve(admin_override, organizer_val, global_default):
        if admin_override is not None:
            return admin_override
        if organizer_val is not None:
            return organizer_val
        return global_default

    return {
        "waitlist_max_size": _resolve(
            event.admin_override_waitlist_max_size,
            event.waitlist_max_size,
            await s.get_int(db, "waitlist_max_size_limit"),
        ),
        "event_max_images": _resolve(
            event.admin_override_event_max_images,
            event.event_max_images,
            await s.get_int(db, "event_max_images_limit"),
        ),
        "max_posts_per_day": _resolve(
            event.admin_override_max_posts_per_day,
            event.max_posts_per_day,
            await s.get_int(db, "max_posts_per_event_limit"),
        ),
        "max_co_organizers": _resolve(
            event.admin_override_max_co_organizers,
            event.max_co_organizers,
            await s.get_int(db, "max_co_organizers_limit"),
        ),
        "refund_deadline_percent": _resolve(
            event.admin_override_refund_deadline_percent,
            event.refund_deadline_percent,
            await s.get_int(db, "refund_deadline_percent_max"),
        ),
    }
