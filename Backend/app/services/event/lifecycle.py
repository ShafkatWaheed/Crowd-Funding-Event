"""
Event lifecycle: cancel, reactivate, extend, set_event_date, start_selling, approve/reject extension, delete_or_cancel.
"""
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventOrganizer, EventDiscount, EventStatus
from app.models.ticket import TicketTier, TicketSale, UserEventDiscount
from app.models.funding import Funding
from app.models.user import User
from app.core.exceptions import ForbiddenError, ConflictError

from app.services.event.permissions import user_can_edit_event

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
    from app.services import sponsor as sponsor_service
    await sponsor_service.refund_all_sponsor_payments_for_event(db, event_id=event.id)
    from app.services import ticket as ticket_service
    await ticket_service.refund_all_tickets_for_event(db, event_id=event.id)
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
