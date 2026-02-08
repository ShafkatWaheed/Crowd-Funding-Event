"""
Event CRUD, ownership checks, list filters (city, status, live, organizer).
"""
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event, EventStatus, RegistrationType
from app.models.venue import Venue
from app.models.user import User
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError


def _event_can_edit(user: User, event: Event) -> bool:
    """Organizer owner or admin can edit."""
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
    if not _event_can_edit(user, event):
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
    city: str | None = None,
    status: str | None = None,
    live: bool | None = None,
    registration_type: str | None = None,
    organizer_id: int | None = None,
) -> Sequence[Event]:
    """List events with optional filters. Joins Venue for city filter."""
    conditions = []
    q = select(Event)
    if city is not None:
        q = q.join(Event.venue)
        conditions.append(Venue.city == city)
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
    if not _event_can_edit(user, event):
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
    if not _event_can_edit(user, event):
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
    if not _event_can_edit(user, event):
        raise ForbiddenError("You cannot delete this event")
    if event.status in (EventStatus.draft, EventStatus.pending_approval):
        await db.delete(event)
    else:
        event.status = EventStatus.cancelled
        from app.services import funding as funding_service
        await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
        await db.flush()
