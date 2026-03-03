"""
Event lifecycle: cancel, reactivate, extend, set_event_date, start_selling, approve/reject extension, delete_or_cancel.
"""
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.event import Event, EventStatus
from app.models.user import User
from app.core.exceptions import ForbiddenError, ConflictError
from app.repositories.event_repo import event_repo

from app.services.event.permissions import user_can_edit_event

logger = get_logger("svc.event.lifecycle")


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
            logger.warning(
                "Cancellation blocked; pending admin approval",
                extra={"event_id": event.id, "pledge_percent": pledge_pct, "threshold": threshold, "user_id": user.id},
            )
            from datetime import datetime, timezone
            event.pending_cancellation = {
                "reason": reason or "Organizer requested cancellation",
                "requested_at": datetime.now(timezone.utc).isoformat(),
                "requested_by": user.id,
                "pledge_percent": pledge_pct,
            }
            await event_repo.flush_and_refresh(db, event)
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
    log_step(logger, "Cancel event", event_id=event.id, user_id=user.id, current_status=event.status.value)
    if not await user_can_edit_event(db, event, user):
        logger.warning("Cancel denied: no edit permission", extra={"event_id": event.id, "user_id": user.id})
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
        await event_repo.flush_and_refresh(db, event)
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
    logger.info("Event cancelled", extra={"event_id": event.id, "user_id": user.id})
    from app.services import funding as funding_service
    await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
    from app.services import sponsor as sponsor_service
    await sponsor_service.refund_all_sponsor_payments_for_event(db, event_id=event.id)
    from app.services import ticket as ticket_service
    await ticket_service.refund_all_tickets_for_event(db, event_id=event.id)

    from app.models.escrow import EscrowStatus
    fund_esc, ticket_esc, sponsor_esc = await event_repo.get_escrow_records(db, event.id)
    for esc in (fund_esc, ticket_esc, sponsor_esc):
        if esc and esc.status not in (EscrowStatus.fully_released, EscrowStatus.refunded):
            esc.status = EscrowStatus.refunded

    await event_repo.flush_and_refresh(db, event)
    return event


async def reactivate_event(db: AsyncSession, event: Event, user: User) -> Event:
    """
    Move a cancelled event back to draft so the organizer can edit and republish it.
    Only allowed when status is cancelled.
    """
    log_step(logger, "Reactivate event", event_id=event.id, user_id=user.id)
    if not await user_can_edit_event(db, event, user):
        logger.warning("Reactivate denied: no edit permission", extra={"event_id": event.id, "user_id": user.id})
        raise ForbiddenError("You cannot reactivate this event")
    if event.status != EventStatus.cancelled:
        raise ConflictError("Only cancelled events can be moved back to draft")
    event.status = EventStatus.draft
    logger.info("Event reactivated to draft", extra={"event_id": event.id, "user_id": user.id})
    await event_repo.flush_and_refresh(db, event)
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
    log_step(logger, "Extend funding", event_id=event.id, user_id=user.id)
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

    logger.debug("Storing pending extension for admin", extra={"event_id": event.id})
    # Organizer: store as pending extension requiring admin approval
    pending: dict = {}
    if new_funding_end_at is not None:
        pending["funding_end_at"] = new_funding_end_at.isoformat()
    if new_funding_goal_cents is not None:
        pending["funding_goal_cents"] = new_funding_goal_cents
    event.pending_extension = pending
    await event_repo.flush_event(db)
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
    Applies directly (no admin approval). Does NOT auto-transition -- organizer must
    manually start selling tickets via the dedicated action.
    """
    log_step(logger, "Set event date", event_id=event.id, user_id=user.id)
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

    await event_repo.flush_event(db)
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
    log_step(logger, "Start selling tickets", event_id=event.id, user_id=user.id)
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot update this event")
    if event.status not in (EventStatus.waiting_event_date, EventStatus.approved):
        raise ConflictError(f"Cannot start selling tickets from {event.status.value} status")
    if event.start_time is None or event.end_time is None:
        raise ConflictError("Event start and end times must be set before selling tickets")
    if event.ticket_strategy_id is None:
        raise ConflictError("A ticket strategy is required before selling tickets")
    has_tiers = await event_repo.has_ticket_tiers(db, event.id)
    if not has_tiers:
        raise ConflictError("At least one ticket tier must exist before selling tickets")
    # If approved with active funding, don't allow early ticket sales
    if event.status == EventStatus.approved and event.funding_end_at is not None:
        now = datetime.now(timezone.utc)
        funding_end = event.funding_end_at if event.funding_end_at.tzinfo else event.funding_end_at.replace(tzinfo=timezone.utc)
        if now < funding_end:
            raise ConflictError("Cannot start selling tickets while funding is still active")

    event.status = EventStatus.selling_tickets
    event.ticket_selling_started_at = datetime.now(timezone.utc)
    logger.info("Event transitioned to selling_tickets", extra={"event_id": event.id})
    await event_repo.flush_event(db)
    return event


async def approve_extension(db: AsyncSession, event: Event, admin: User) -> Event:
    """Admin approves a pending funding extension."""
    log_step(logger, "Approve extension", event_id=event.id, admin_id=admin.id)
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
    log_step(logger, "Reject extension", event_id=event.id, admin_id=admin.id)
    if admin.role.value != "admin":
        raise ForbiddenError("Only admin can reject extensions")
    if not event.pending_extension:
        raise ConflictError("No pending extension to reject")
    event.pending_extension = None
    await event_repo.flush_event(db)
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
    await event_repo.flush_event(db)
    return event


async def approve_cancellation(db: AsyncSession, event: Event) -> Event:
    """Admin approves a pending cancellation — cancel event, issue all refunds, send email."""
    log_step(logger, "Approve cancellation", event_id=event.id)
    reason = event.pending_cancellation.get("reason", "Admin-approved cancellation")
    event.pending_cancellation = None
    event.status = EventStatus.cancelled
    event.cancellation_reason = reason

    from app.services import funding as funding_service
    from app.services import sponsor as sponsor_service
    from app.services import ticket as ticket_service
    await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
    await sponsor_service.refund_all_sponsor_payments_for_event(db, event_id=event.id)
    await ticket_service.refund_all_tickets_for_event(db, event_id=event.id)
    await event_repo.flush_event(db)

    from app.worker.redis_pool import enqueue as arq_enqueue
    await arq_enqueue(
        "send_event_cancelled_email",
        event.id,
        event.title or f"Event #{event.id}",
        reason,
        event.start_time,
    )
    return event


async def reject_cancellation(db: AsyncSession, event: Event) -> Event:
    """Admin rejects a pending cancellation — clear the pending flag."""
    log_step(logger, "Reject cancellation", event_id=event.id)
    event.pending_cancellation = None
    await event_repo.flush_event(db)
    return event


async def delete_or_cancel(db: AsyncSession, event: Event, user: User) -> None:
    """
    Delete event (hard) if draft or cancelled; otherwise set status to cancelled (soft).
    If >=80% funded, routes to admin approval queue instead.
    Raises ForbiddenError if user cannot edit.
    """
    log_step(logger, "Delete or cancel event", event_id=event.id, user_id=user.id, status=event.status.value)
    if not await user_can_edit_event(db, event, user):
        logger.warning("Delete/cancel denied: no edit permission", extra={"event_id": event.id, "user_id": user.id})
        raise ForbiddenError("You cannot delete this event")
    if event.status in (EventStatus.draft, EventStatus.cancelled):
        logger.info("Event hard deleted", extra={"event_id": event.id})
        await event_repo.purge_event_children(db, event.id)
        await event_repo.delete_event(db, event)
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
        await event_repo.flush_event(db)
