"""
Event CRUD, ownership checks, list filters (city, status, live, organizer, search, date, capacity, has_funding, has_tickets).
"""
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import select, and_, or_, exists
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event, EventOrganizer, EventStatus, RegistrationType
from app.models.venue import Venue
from app.models.user import User
from app.models.ticket import TicketTier
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError


def _event_can_edit(user: User, event: Event) -> bool:
    """Main organizer or admin (sync check, no co-organizers)."""
    return user.role.value == "admin" or event.organizer_id == user.id


async def user_can_edit_event(db: AsyncSession, event: Event, user: User) -> bool:
    """True if user is admin, main organizer, or co-organizer for this event."""
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
        q = q.options(selectinload(Event.venue))
    if load_organizer:
        q = q.options(selectinload(Event.organizer))
    result = await db.execute(q)
    return result.scalar_one_or_none()


async def get_or_404(db: AsyncSession, event_id: int) -> Event:
    """Load event by id or raise 404."""
    event = await get_by_id(db, event_id)
    if not event:
        raise NotFoundError("Event", event_id)
    return event


async def submit_for_approval(db: AsyncSession, event_id: int, user: User) -> Event:
    """
    Submit event for admin approval (draft → pending_approval).
    Only the organizer (or admin) can submit; event must be in draft status.
    """
    event = await get_or_404(db, event_id)
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot submit this event")
    if event.status != EventStatus.draft:
        raise ConflictError("Only draft events can be submitted for approval")
    event.status = EventStatus.pending_approval
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
) -> Sequence[Event]:
    """List events with optional filters: full-text search, city, date range, has_funding, has_tickets, capacity."""
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
    if live is True:
        now = datetime.now(timezone.utc)
        conditions.append(Event.start_time <= now)
        conditions.append(Event.end_time >= now)
        conditions.append(Event.status.in_([EventStatus.approved, EventStatus.live]))
    if registration_type is not None:
        try:
            reg_type = RegistrationType(registration_type)
        except ValueError:
            return []
        conditions.append(Event.registration_type == reg_type)
    if organizer_id is not None:
        conditions.append(Event.organizer_id == organizer_id)
    if date_from is not None:
        conditions.append(Event.start_time >= date_from)
    if date_to is not None:
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
    if conditions:
        q = q.where(and_(*conditions))
    q = q.options(selectinload(Event.venue)).order_by(Event.start_time.asc())
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
    import math
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
        conditions.append(Event.start_time <= now)
        conditions.append(Event.end_time >= now)
        conditions.append(Event.status.in_([EventStatus.approved, EventStatus.live]))
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
    start_time: datetime,
    end_time: datetime,
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
) -> Event:
    """Create event. Venue must exist; organizer can only use their own venue (admin can use any)."""
    venue_result = await db.execute(select(Venue).where(Venue.id == venue_id))
    venue = venue_result.scalar_one_or_none()
    if not venue:
        raise NotFoundError("Venue", venue_id)
    if not allow_any_venue and venue.organizer_id != organizer_id:
        raise ForbiddenError("You can only create events at your own venues")
    if end_time <= start_time:
        raise ConflictError("end_time must be after start_time")
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
        status=EventStatus.draft,
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
    funding_goal_cents: int | None = None,
    funding_end_at: datetime | None = None,
    min_pledge_cents: int | None = None,
    registration_type: RegistrationType | None = None,
    max_capacity: int | None = None,
    common_discount_percent: int | None = None,
    pledge_discount_percent: int | None = None,
) -> Event:
    """Update event fields (only provided ones). When switching closed→open, auto-approve waitlist up to capacity."""
    old_registration_type = event.registration_type
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
    if event.end_time <= event.start_time:
        raise ConflictError("end_time must be after start_time")
    await db.flush()
    if registration_type is not None and old_registration_type == RegistrationType.closed and registration_type == RegistrationType.open:
        from app.services import registration as registration_service
        await registration_service.auto_approve_waitlist_when_switching_to_open(
            db, event_id=event.id, event_max_capacity=event.max_capacity
        )
    await db.refresh(event)
    return event


async def cancel_event(db: AsyncSession, event: Event, user: User) -> Event:
    """
    Organizer cancels the event (anytime). Sets status to cancelled and refunds all pledges.
    Not allowed if event is already cancelled or ended.
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot cancel this event")
    if event.status == EventStatus.cancelled:
        raise ConflictError("Event is already cancelled")
    if event.status == EventStatus.ended:
        raise ConflictError("Cannot cancel an ended event")
    event.status = EventStatus.cancelled
    from app.services import funding as funding_service
    await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
    await db.flush()
    await db.refresh(event)
    return event


async def extend_funding_and_set_event_date(
    db: AsyncSession,
    event: Event,
    user: User,
    *,
    new_funding_end_at: datetime | None = None,
    new_start_time: datetime | None = None,
    new_end_time: datetime | None = None,
) -> Event:
    """
    After funding deadline, organizer can extend the funding period and/or set event date.
    Gives customers new time to unregister or commit. Any of the three can be provided.
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot update this event")
    if event.status == EventStatus.cancelled:
        raise ConflictError("Cannot extend a cancelled event")
    if event.status == EventStatus.ended:
        raise ConflictError("Cannot extend an ended event")
    if new_funding_end_at is not None:
        event.funding_end_at = new_funding_end_at
    if new_start_time is not None:
        event.start_time = new_start_time
    if new_end_time is not None:
        event.end_time = new_end_time
    if event.end_time <= event.start_time:
        raise ConflictError("end_time must be after start_time")
    await db.flush()
    await db.refresh(event)
    return event


async def delete_or_cancel(db: AsyncSession, event: Event, user: User) -> None:
    """
    Delete event (hard) if draft or pending_approval; otherwise set status to cancelled (soft).
    Raises ForbiddenError if user cannot edit.
    """
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot delete this event")
    if event.status in (EventStatus.draft, EventStatus.pending_approval):
        await db.delete(event)
    else:
        event.status = EventStatus.cancelled
        from app.services import funding as funding_service
        await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
        await db.flush()


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


async def add_event_organizer(db: AsyncSession, *, event_id: int, user_id: int, added_by: User) -> EventOrganizer:
    """Main organizer adds a co-organizer. User must have role organizer."""
    event = await get_or_404(db, event_id)
    if not is_main_organizer(added_by, event):
        raise ForbiddenError("Only the main organizer can add co-organizers")
    if user_id == event.organizer_id:
        raise ConflictError("User is already the main organizer")
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
    eo = EventOrganizer(event_id=event_id, user_id=user_id)
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
