"""
Registrations: open/closed behavior, capacity enforcement, waitlist.

Rules (MVP):
- One active registration per user per event (registered/waitlist). If cancelled exists, re-activate it.
- Open event: if registered_count < max_capacity -> registered else waitlist.
- Closed event: always waitlist (acts like a request) until organizer approves.

Unregister: Customer can unregister anytime. Pledges are refunded only if the event's
refund_deadline_days has not been exceeded (counted backwards from event start_time).
If the deadline has passed, unregister is allowed but pledges are NOT refunded.

Concurrency:
- Uses pg_advisory_xact_lock(event_id) + SELECT ... FOR UPDATE on the event row
  when registering to prevent oversubscription under burst load (same pattern as
  purchase_ticket and create_pledge).
"""



from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.core.exceptions import ConflictError, NotFoundError
from app.models.event import Event, EventStatus, RegistrationType
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User
from app.services import funding as funding_service

logger = get_logger("svc.registration")


async def register(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
) -> Registration:
    log_step(logger, "Register for event", event_id=event_id, user_id=user.id)
    await db.execute(text("SELECT pg_advisory_xact_lock(:eid)"), {"eid": event_id})
    event_q = select(Event).where(Event.id == event_id).with_for_update()
    event_res = await db.execute(event_q)
    event = event_res.scalar_one_or_none()
    if not event:
        raise NotFoundError("Event", event_id)

    if event.status == EventStatus.cancelled:
        logger.warning("Register rejected: event cancelled", extra={"event_id": event_id, "user_id": user.id})
        raise ConflictError("Cannot register for a cancelled event")
    if event.status == EventStatus.completed:
        logger.warning("Register rejected: event completed", extra={"event_id": event_id, "user_id": user.id})
        raise ConflictError("Cannot register for an ended event")

    from app.services.age_verification import enforce_age_limit
    enforce_age_limit(user.birthday, event.age_restricted, event.min_age, "register for this event")

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

    # Enforce waitlist size limit
    if target_status == RegistrationStatus.waitlist:
        from app.services.event.crud import get_effective_policy
        policy = await get_effective_policy(db, event)
        max_waitlist = policy.get("waitlist_max_size")
        if max_waitlist and max_waitlist > 0:
            wl_count = (await db.execute(
                select(func.count()).where(
                    Registration.event_id == event_id,
                    Registration.status == RegistrationStatus.waitlist,
                )
            )).scalar_one()
            if int(wl_count) >= max_waitlist:
                logger.warning("Register rejected: waitlist full", extra={"event_id": event_id, "user_id": user.id, "max_waitlist": max_waitlist})
                raise ConflictError(f"Waitlist is full ({max_waitlist} max)")

    if existing:
        if existing.status == RegistrationStatus.cancelled:
            existing.status = target_status
            if target_status == RegistrationStatus.registered:
                event.registration_count = (event.registration_count or 0) + 1
            await db.flush()
            await db.refresh(existing)
            return existing
        logger.warning("Register rejected: already registered", extra={"event_id": event_id, "user_id": user.id, "status": existing.status.value})
        raise ConflictError(f"Already {existing.status.value} for this event")

    reg = Registration(event_id=event_id, user_id=user.id, status=target_status)
    db.add(reg)
    if target_status == RegistrationStatus.registered:
        event.registration_count = (event.registration_count or 0) + 1
    await db.flush()
    await db.refresh(reg)
    logger.info("User registered", extra={"event_id": event_id, "user_id": user.id, "status": target_status.value})
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
    log_step(logger, "Approve waitlist", event_id=event_id, registration_id=registration_id)
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

    if event.status in (EventStatus.cancelled, EventStatus.completed):
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

    from app.services import notification_service as notif_svc
    from app.models.notification import NotificationType
    await notif_svc.create_notification(
        db, user_id=reg.user_id,
        type=NotificationType.waitlist_approved,
        title="Waitlist Approved",
        message="Your registration has been approved!",
        data={"event_id": reg.event_id},
    )
    return reg


async def reject_waitlist(
    db: AsyncSession, *, event_id: int, registration_id: int
) -> Registration:
    """
    Reject a waitlist request → mark cancelled.
    """
    log_step(logger, "Reject waitlist", event_id=event_id, registration_id=registration_id)
    reg = await get_registration_or_404(db, event_id=event_id, registration_id=registration_id)
    if reg.status != RegistrationStatus.waitlist:
        raise ConflictError("Only waitlist registrations can be rejected")
    reg.status = RegistrationStatus.cancelled
    await db.flush()
    await db.refresh(reg)

    from app.services import notification_service as notif_svc
    from app.models.notification import NotificationType
    await notif_svc.create_notification(
        db, user_id=reg.user_id,
        type=NotificationType.waitlist_rejected,
        title="Waitlist Rejected",
        message="Your registration request was not approved.",
        data={"event_id": reg.event_id},
    )
    return reg


async def unregister(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
) -> dict:
    """
    Customer unregisters from event. Registration is set to cancelled.
    Pledges are refunded only if the organizer's refund_deadline_days has not passed
    (counted backwards from event start_time).
    Returns {"refunded_cents": int, "pledges_refunded": int, "refund_eligible": bool}.
    """
    log_step(logger, "Unregister from event", event_id=event_id, user_id=user.id)
    from datetime import datetime, timedelta, timezone

    event = await _get_event_for_unregister(db, event_id=event_id)
    reg = await _get_user_registration(db, event_id=event_id, user_id=user.id)
    if reg.status == RegistrationStatus.cancelled:
        logger.warning("Unregister rejected: not registered", extra={"event_id": event_id, "user_id": user.id})
        raise ConflictError("You are not registered for this event")

    # Check if we are still within the refund window
    now = datetime.now(timezone.utc)
    event_start = event.start_time
    if event_start is not None:
        if event_start.tzinfo is None:
            event_start = event_start.replace(tzinfo=timezone.utc)
        deadline_days = event.refund_deadline_days if event.refund_deadline_days is not None else 7
        refund_cutoff = event_start - timedelta(days=deadline_days)
        refund_eligible = now <= refund_cutoff
    else:
        # No start time set — use funding_end_at or default to eligible
        fund_end = event.funding_end_at
        if fund_end is not None:
            if fund_end.tzinfo is None:
                fund_end = fund_end.replace(tzinfo=timezone.utc)
            deadline_days = event.refund_deadline_days if event.refund_deadline_days is not None else 7
            refund_cutoff = fund_end - timedelta(days=deadline_days)
            refund_eligible = now <= refund_cutoff
        else:
            refund_eligible = True

    refunded_cents = 0
    pledges_refunded = 0

    if refund_eligible:
        pledges = await _get_pledges_for_refund(db, event_id=event_id, user_id=user.id)
        for p in pledges:
            refunded_cents += p.amount_cents
        pledges_refunded = await funding_service.refund_pledges_for_user_event(
            db, event_id=event_id, user_id=user.id
        )

    reg.status = RegistrationStatus.cancelled
    event.registration_count = max(0, (event.registration_count or 1) - 1)
    await db.flush()
    logger.info("User unregistered", extra={"event_id": event_id, "user_id": user.id, "refunded_cents": refunded_cents, "pledges_refunded": pledges_refunded, "refund_eligible": refund_eligible})
    return {"refunded_cents": refunded_cents, "pledges_refunded": pledges_refunded, "refund_eligible": refund_eligible}


async def _get_event_for_unregister(db: AsyncSession, *, event_id: int) -> Event:
    q = select(Event).where(Event.id == event_id)
    res = await db.execute(q)
    event = res.scalar_one_or_none()
    if not event:
        raise NotFoundError("Event", event_id)
    if event.status == EventStatus.cancelled:
        raise ConflictError("Cannot unregister from a cancelled event")
    if event.status == EventStatus.completed:
        raise ConflictError("Cannot unregister from an ended event")
    return event


async def _get_user_registration(
    db: AsyncSession, *, event_id: int, user_id: int
) -> Registration:
    q = select(Registration).where(
        Registration.event_id == event_id,
        Registration.user_id == user_id,
    )
    res = await db.execute(q)
    reg = res.scalar_one_or_none()
    if not reg:
        raise NotFoundError("Registration", "user not registered for this event")
    return reg


async def _get_pledges_for_refund(
    db: AsyncSession, *, event_id: int, user_id: int
) -> list:
    from app.models.funding import Funding, FundingStatus
    q = select(Funding).where(
        Funding.event_id == event_id,
        Funding.user_id == user_id,
        Funding.status == FundingStatus.pledged,
    )
    res = await db.execute(q)
    return list(res.scalars().all())


async def auto_approve_waitlist_when_switching_to_open(
    db: AsyncSession,
    *,
    event_id: int,
    event_max_capacity: int,
) -> int:
    """
    When organizer changes event from closed to open, approve waitlist entries
    in order (first-come) until we reach max_capacity. Returns number approved.
    """
    registered_count_q = select(func.count()).where(
        Registration.event_id == event_id,
        Registration.status == RegistrationStatus.registered,
    )
    current_registered = int((await db.execute(registered_count_q)).scalar_one())
    slots = max(0, event_max_capacity - current_registered)
    if slots == 0:
        return 0
    # First N waitlist by created_at
    waitlist_q = (
        select(Registration)
        .where(
            Registration.event_id == event_id,
            Registration.status == RegistrationStatus.waitlist,
        )
        .order_by(Registration.created_at.asc())
        .limit(slots)
    )
    res = await db.execute(waitlist_q)
    to_approve = list(res.scalars().all())
    for reg in to_approve:
        reg.status = RegistrationStatus.registered
    if to_approve:
        await db.flush()
    return len(to_approve)
