"""
Registrations: open/closed behavior, capacity enforcement, waitlist.

Rules (MVP):
- One active registration per user per event (registered/waitlist). If cancelled exists, re-activate it.
- Open event: if registered_count < max_capacity -> registered else waitlist.
- Closed event: always waitlist (acts like a request) until organizer approves (future endpoint).

Concurrency:
- Uses SELECT ... FOR UPDATE on the event row when registering to reduce oversubscription.
"""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.models.event import Event, EventStatus, RegistrationType
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User


async def register(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
) -> Registration:
    # Lock event row to reduce capacity races
    event_q = select(Event).where(Event.id == event_id).with_for_update()
    event_res = await db.execute(event_q)
    event = event_res.scalar_one_or_none()
    if not event:
        raise NotFoundError("Event", event_id)

    if event.status == EventStatus.cancelled:
        raise ConflictError("Cannot register for a cancelled event")
    if event.status == EventStatus.ended:
        raise ConflictError("Cannot register for an ended event")

    # Existing registration?
    existing_q = select(Registration).where(
        Registration.event_id == event_id,
        Registration.user_id == user.id,
    )
    existing_res = await db.execute(existing_q)
    existing = existing_res.scalar_one_or_none()

    # Determine target status
    target_status: RegistrationStatus
    if event.registration_type == RegistrationType.closed:
        target_status = RegistrationStatus.waitlist
    else:
        # Open: decide based on capacity
        registered_count_q = select(func.count()).where(
            Registration.event_id == event_id,
            Registration.status == RegistrationStatus.registered,
        )
        registered_count = (await db.execute(registered_count_q)).scalar_one()
        target_status = (
            RegistrationStatus.registered
            if int(registered_count) < int(event.max_capacity)
            else RegistrationStatus.waitlist
        )

    if existing:
        if existing.status == RegistrationStatus.cancelled:
            existing.status = target_status
            await db.flush()
            await db.refresh(existing)
            return existing
        # Already registered or waitlisted
        raise ConflictError(f"Already {existing.status.value} for this event")

    reg = Registration(event_id=event_id, user_id=user.id, status=target_status)
    db.add(reg)
    await db.flush()
    await db.refresh(reg)
    return reg


async def list_registrations(db: AsyncSession, *, event_id: int) -> list[Registration]:
    q = select(Registration).where(Registration.event_id == event_id).order_by(Registration.created_at.asc())
    res = await db.execute(q)
    return list(res.scalars().all())


async def get_registration_or_404(
    db: AsyncSession, *, event_id: int, registration_id: int
) -> Registration:
    q = select(Registration).where(
        Registration.id == registration_id,
        Registration.event_id == event_id,
    )
    res = await db.execute(q)
    reg = res.scalar_one_or_none()
    if not reg:
        raise NotFoundError("Registration", registration_id)
    return reg


async def approve_waitlist(
    db: AsyncSession, *, event_id: int, registration_id: int
) -> Registration:
    """
    Approve a waitlist request → move to registered if capacity allows.
    Uses row locks to reduce races.
    """
    # Lock event first (capacity gate)
    event_q = select(Event).where(Event.id == event_id).with_for_update()
    event_res = await db.execute(event_q)
    event = event_res.scalar_one_or_none()
    if not event:
        raise NotFoundError("Event", event_id)

    # Lock the registration row
    reg_q = select(Registration).where(
        Registration.id == registration_id,
        Registration.event_id == event_id,
    ).with_for_update()
    reg_res = await db.execute(reg_q)
    reg = reg_res.scalar_one_or_none()
    if not reg:
        raise NotFoundError("Registration", registration_id)

    if reg.status != RegistrationStatus.waitlist:
        raise ConflictError("Only waitlist registrations can be approved")

    if event.status in (EventStatus.cancelled, EventStatus.ended):
        raise ConflictError("Cannot approve registrations for this event status")

    # Capacity check
    registered_count_q = select(func.count()).where(
        Registration.event_id == event_id,
        Registration.status == RegistrationStatus.registered,
    )
    registered_count = int((await db.execute(registered_count_q)).scalar_one())
    if registered_count >= int(event.max_capacity):
        raise ConflictError("Event is full")

    reg.status = RegistrationStatus.registered
    await db.flush()
    await db.refresh(reg)
    return reg


async def reject_waitlist(
    db: AsyncSession, *, event_id: int, registration_id: int
) -> Registration:
    """
    Reject a waitlist request → mark cancelled.
    """
    reg = await get_registration_or_404(db, event_id=event_id, registration_id=registration_id)
    if reg.status != RegistrationStatus.waitlist:
        raise ConflictError("Only waitlist registrations can be rejected")
    reg.status = RegistrationStatus.cancelled
    await db.flush()
    await db.refresh(reg)
    return reg
