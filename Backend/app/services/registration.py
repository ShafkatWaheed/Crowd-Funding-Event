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



from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.core.exceptions import ConflictError, NotFoundError
from app.models.event import EventStatus, RegistrationType
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User
from app.repositories.funding_repo import funding_repo
from app.repositories.registration_repo import registration_repo
from app.repositories.ticket_repo import ticket_repo
from app.services import funding as funding_service


logger = get_logger("svc.registration")


async def register(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
) -> Registration:
    log_step(logger, "Register for event", event_id=event_id, user_id=user.id)
    await registration_repo.advisory_lock(db, event_id)
    event = await registration_repo.get_event_for_update(db, event_id)
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
    existing = await registration_repo.get_existing_registration(db, event_id, user.id)

    # Determine target status
    target_status: RegistrationStatus
    if event.registration_type == RegistrationType.closed:
        target_status = RegistrationStatus.waitlist
    else:
        # Open: decide based on capacity (registered + reserved guest spots must not exceed max)
        registered_count = await registration_repo.count_registered(db, event_id)
        total_reserved = await funding_service.get_total_reserved_spots(db, event_id)
        target_status = (
            RegistrationStatus.registered
            if registered_count + total_reserved < int(event.max_capacity)
            else RegistrationStatus.waitlist
        )

    # Enforce waitlist size limit
    if target_status == RegistrationStatus.waitlist:
        from app.services.event.crud import get_effective_policy
        policy = await get_effective_policy(db, event)
        max_waitlist = policy.get("waitlist_max_size")
        if max_waitlist and max_waitlist > 0:
            wl_count = await registration_repo.count_waitlisted(db, event_id)
            if wl_count >= max_waitlist:
                logger.warning("Register rejected: waitlist full", extra={"event_id": event_id, "user_id": user.id, "max_waitlist": max_waitlist})
                raise ConflictError(f"Waitlist is full ({max_waitlist} max)")

    if existing:
        if existing.status == RegistrationStatus.cancelled:
            return await registration_repo.update_registration_status(
                db, existing, target_status, event=event if target_status == RegistrationStatus.registered else None,
            )
        logger.warning("Register rejected: already registered", extra={"event_id": event_id, "user_id": user.id, "status": existing.status.value})
        raise ConflictError(f"Already {existing.status.value} for this event")

    reg = await registration_repo.create_registration(db, event_id, user.id, target_status)
    if target_status == RegistrationStatus.registered:
        from app.repositories.event_repo import event_repo
        await event_repo.update_fields(db, event, registration_count=(event.registration_count or 0) + 1)
    logger.info("User registered", extra={"event_id": event_id, "user_id": user.id, "status": target_status.value})
    return reg


async def list_registrations(
    db: AsyncSession, *, event_id: int, offset: int = 0, limit: int = 20,
) -> list[Registration]:
    return await registration_repo.list_by_event(db, event_id, offset=offset, limit=limit)


async def get_registration_or_404(
    db: AsyncSession, *, event_id: int, registration_id: int
) -> Registration:
    reg = await registration_repo.get_by_id(db, event_id, registration_id)
    if not reg:
        raise NotFoundError("Registration", registration_id)
    return reg


async def approve_waitlist(
    db: AsyncSession, *, event_id: int, registration_id: int
) -> Registration:
    """
    Approve a waitlist request -> move to registered if capacity allows.
    Uses row locks to reduce races.
    """
    log_step(logger, "Approve waitlist", event_id=event_id, registration_id=registration_id)
    # Lock event first (capacity gate)
    event = await registration_repo.get_event_for_update(db, event_id)
    if not event:
        raise NotFoundError("Event", event_id)

    # Lock the registration row
    reg = await registration_repo.get_by_id_for_update(db, event_id, registration_id)
    if not reg:
        raise NotFoundError("Registration", registration_id)

    if reg.status != RegistrationStatus.waitlist:
        raise ConflictError("Only waitlist registrations can be approved")

    if event.status in (EventStatus.cancelled, EventStatus.completed):
        raise ConflictError("Cannot approve registrations for this event status")

    # Capacity check
    registered_count = await registration_repo.count_registered(db, event_id)
    if registered_count >= int(event.max_capacity):
        raise ConflictError("Event is full")

    reg = await registration_repo.update_registration_status(db, reg, RegistrationStatus.registered)

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
    Reject a waitlist request -> mark cancelled.
    """
    log_step(logger, "Reject waitlist", event_id=event_id, registration_id=registration_id)
    reg = await get_registration_or_404(db, event_id=event_id, registration_id=registration_id)
    if reg.status != RegistrationStatus.waitlist:
        raise ConflictError("Only waitlist registrations can be rejected")

    reg = await registration_repo.update_registration_status(db, reg, RegistrationStatus.cancelled)

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

    # For selling_tickets / live events: only allow unregister if the user has
    # no active ticket purchases AND no active pledges.
    # Active pledges cannot be refunded once the event is in selling/live state,
    # so unregistering would silently forfeit the pledged amount.
    if event.status in (EventStatus.selling_tickets, EventStatus.live):
        if await ticket_repo.has_active_ticket_sales(db, event_id, user.id):
            raise ConflictError("Cannot unregister — you have active ticket purchases for this event")
        if await funding_repo.has_active_pledges(db, event_id, user.id):
            raise ConflictError("Cannot unregister — you have an active pledge that can no longer be refunded")

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
        # No start time set -- use funding_end_at or default to eligible
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
        pledges = await registration_repo.get_pledges_for_refund(db, event_id, user.id)
        for p in pledges:
            refunded_cents += p.amount_cents
        pledges_refunded = await funding_service.refund_pledges_for_user_event(
            db, event_id=event_id, user_id=user.id
        )

    await registration_repo.update_registration_status(db, reg, RegistrationStatus.cancelled)
    from app.repositories.event_repo import event_repo
    await event_repo.update_fields(db, event, registration_count=max(0, (event.registration_count or 1) - 1))
    logger.info("User unregistered", extra={"event_id": event_id, "user_id": user.id, "refunded_cents": refunded_cents, "pledges_refunded": pledges_refunded, "refund_eligible": refund_eligible})
    return {"refunded_cents": refunded_cents, "pledges_refunded": pledges_refunded, "refund_eligible": refund_eligible}


async def _get_event_for_unregister(db: AsyncSession, *, event_id: int):
    event = await registration_repo.get_event(db, event_id)
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
    reg = await registration_repo.get_user_registration(db, event_id, user_id)
    if not reg:
        raise NotFoundError("Registration", "user not registered for this event")
    return reg


async def auto_register(db: AsyncSession, *, event_id: int, user_id: int) -> None:
    """Silently register a user without capacity check (ticket purchase gate is the real gate).

    Used during selling_tickets/live when a user attempts to purchase without prior registration.
    If a registration row already exists in any state, promote it to registered.
    Otherwise create a new registered row and increment registration_count.
    """
    from app.repositories.event_repo import event_repo
    reg = await registration_repo.get_existing_registration(db, event_id, user_id)
    event = await event_repo.get_by_id(db, event_id)
    if reg:
        if reg.status != RegistrationStatus.registered:
            await registration_repo.update_registration_status(
                db, reg, RegistrationStatus.registered, event=event,
            )
    else:
        await registration_repo.create_registration(
            db, event_id, user_id, RegistrationStatus.registered,
        )
        if event:
            await event_repo.update_fields(db, event, registration_count=(event.registration_count or 0) + 1)


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
    current_registered = await registration_repo.count_registered(db, event_id)
    slots = max(0, event_max_capacity - current_registered)
    if slots == 0:
        return 0
    # First N waitlist by created_at
    to_approve = await registration_repo.get_waitlist_to_approve(db, event_id, slots)
    await registration_repo.bulk_approve_waitlist(db, to_approve)
    return len(to_approve)
