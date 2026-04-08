"""
Event lifecycle: cancel, extend-funding, set-event-date, start-selling, reactivate, publish, clone, extension-decision, cancellation/approve.
"""
from fastapi import APIRouter, Depends, HTTPException, Request

from app.dependencies import DbSession, require_role
from app.logger import get_logger, log_step
from app.rate_limit import limiter, dynamic_limit
from app.models.event import EventStatus
from app.models.user import User, UserRole
from app.schemas import CancelBody, EventResponse, ExtendFundingBody, ExtensionApprovalAction, SetEventDateBody
from app.core.exceptions import ForbiddenError
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import sponsor as sponsor_service
from app.services import ticket as ticket_service
from app.services import notification_service as notif_svc
from app.worker.redis_pool import enqueue as arq_enqueue
from app.models.notification import NotificationType

from app.cache import invalidate_event_cascade

from ._helpers import _event_to_response, _parse_iso_datetime

router = APIRouter()
logger = get_logger("api.events.lifecycle")


async def _invalidate_event_cache(event_id: int) -> None:
    await invalidate_event_cascade(event_id)


@router.post("/{event_id}/cancel", response_model=EventResponse)
async def cancel_event(
    event_id: int,
    body: CancelBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Organizer (main or co-) cancels the event. A reason is required."""
    log_step(logger, "Cancelling event", user_id=current_user.id, event_id=event_id)
    from app.models.funding import FundingStatus
    from app.repositories.event_repo import event_repo
    from app.repositories.funding_repo import funding_repo

    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        logger.warning("Cancel rejected: user cannot edit event", extra={"user_id": current_user.id, "event_id": event_id})
        raise ForbiddenError("You cannot cancel this event")
    event = await event_service.cancel_event(db, event, current_user, reason=body.reason)
    await arq_enqueue(
        "send_event_cancelled_email",
        event.id,
        event.title or f"Event #{event.id}",
        body.reason,
        event.start_time,
    )
    affected_ids = await event_repo.get_active_registrant_ids(db, event.id)
    pledger_ids = await funding_repo.get_funder_ids(
        db, event.id, [FundingStatus.pledged, FundingStatus.refunded],
    )
    all_ids = list(set(affected_ids + pledger_ids))
    if all_ids:
        await notif_svc.create_bulk_notifications(
            db, user_ids=all_ids,
            type=NotificationType.event_cancelled,
            title="Event Cancelled",
            message=f'"{event.title}" has been cancelled. {body.reason or ""}',
            data={"event_id": event.id},
        )
    await _invalidate_event_cache(event_id)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/extend-funding", response_model=EventResponse)
async def extend_funding_endpoint(
    event_id: int,
    body: ExtendFundingBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Extend funding: new deadline and/or new goal. Requires admin approval for organizers."""
    log_step(logger, "Extending funding", user_id=current_user.id, event_id=event_id)
    event = await event_service.get_or_404(db, event_id)
    if not any([body.funding_end_at, body.funding_goal_cents]):
        logger.warning("Extend funding rejected: missing params", extra={"event_id": event_id})
        raise HTTPException(status_code=400, detail="At least one of funding_end_at or funding_goal_cents required")
    new_funding_end_at = _parse_iso_datetime(body.funding_end_at)
    event = await event_service.extend_funding(
        db, event, current_user,
        new_funding_end_at=new_funding_end_at,
        new_funding_goal_cents=body.funding_goal_cents,
    )
    await _invalidate_event_cache(event_id)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    from app.worker.event_jobs import schedule_event_transitions
    await schedule_event_transitions(event)
    return _event_to_response(event)


@router.post("/{event_id}/set-event-date", response_model=EventResponse)
async def set_event_date_endpoint(
    event_id: int,
    body: SetEventDateBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Set or update event start/end time."""
    log_step(logger, "Setting event date", user_id=current_user.id, event_id=event_id)
    event = await event_service.get_or_404(db, event_id)
    new_start = _parse_iso_datetime(body.start_time)
    new_end = _parse_iso_datetime(body.end_time)
    if new_start is None or new_end is None:
        logger.warning("Set event date rejected: invalid datetime params", extra={"event_id": event_id})
        raise HTTPException(status_code=400, detail="Both start_time and end_time are required as valid ISO datetimes")
    if new_start >= new_end:
        logger.warning("Set event date rejected: start >= end", extra={"event_id": event_id})
        raise HTTPException(status_code=400, detail="start_time must be before end_time")
    event = await event_service.set_event_date(
        db, event, current_user,
        new_start_time=new_start,
        new_end_time=new_end,
    )
    await _invalidate_event_cache(event_id)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    from app.worker.event_jobs import schedule_event_transitions
    await schedule_event_transitions(event)
    return _event_to_response(event)


@router.post("/{event_id}/start-selling", response_model=EventResponse)
async def start_selling_tickets_endpoint(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Manually transition event to selling_tickets."""
    log_step(logger, "Starting ticket sales", user_id=current_user.id, event_id=event_id)
    event = await event_service.get_or_404(db, event_id)
    event = await event_service.start_selling_tickets(db, event, current_user)
    await _invalidate_event_cache(event_id)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    from app.worker.event_jobs import schedule_event_transitions
    await schedule_event_transitions(event)
    return _event_to_response(event)


@router.post("/{event_id}/reactivate", response_model=EventResponse)
async def reactivate_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Move a cancelled event back to draft."""
    log_step(logger, "Reactivating event", user_id=current_user.id, event_id=event_id)
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        logger.warning("Reactivate rejected: user cannot edit event", extra={"user_id": current_user.id, "event_id": event_id})
        raise ForbiddenError("You cannot reactivate this event")
    event = await event_service.reactivate_event(db, event, current_user)
    await _invalidate_event_cache(event_id)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/publish", response_model=EventResponse)
async def publish_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Publish a draft event (draft → approved)."""
    log_step(logger, "Publishing event", user_id=current_user.id, event_id=event_id)
    event = await event_service.publish_event(db, event_id=event_id, user=current_user)
    await notif_svc.create_notification(
        db, user_id=current_user.id,
        type=NotificationType.event_approved,
        title="Event Published",
        message=f'Your event "{event.title}" is now live.',
        data={"event_id": event.id},
    )
    await _invalidate_event_cache(event_id)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    from app.worker.event_jobs import schedule_event_transitions
    await schedule_event_transitions(event)
    return _event_to_response(event)


@router.post("/{event_id}/clone", response_model=EventResponse)
@limiter.limit(dynamic_limit("event_create", "5/minute"))
async def clone_event(
    request: Request,
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Clone a completed event into a new draft."""
    log_step(logger, "Cloning event", user_id=current_user.id, event_id=event_id)
    event = await event_service.get_or_404(db, event_id)
    new_event = await event_service.clone_event(db, event, current_user)
    new_event = await event_service.get_by_id(db, new_event.id, load_venue=True)
    return _event_to_response(new_event)


@router.post("/{event_id}/extension-decision", response_model=EventResponse)
async def decide_extension(
    event_id: int,
    body: ExtensionApprovalAction,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin approve/reject a pending funding extension request."""
    log_step(logger, "Extension decision", user_id=current_user.id, event_id=event_id, action=body.action)
    event = await event_service.get_or_404(db, event_id)
    if body.action == "approve":
        event = await event_service.approve_extension(db, event, current_user)
    elif body.action == "reject":
        event = await event_service.reject_extension(db, event, current_user)
    else:
        logger.warning("Extension decision rejected: invalid action", extra={"event_id": event_id, "action": body.action})
        raise HTTPException(status_code=400, detail="action must be 'approve' or 'reject'")
    await _invalidate_event_cache(event_id)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    if body.action == "approve":
        from app.worker.event_jobs import schedule_event_transitions
        await schedule_event_transitions(event)
    return _event_to_response(event)


@router.post("/{event_id}/cancellation/approve", response_model=EventResponse)
async def approve_cancellation(
    event_id: int,
    body: ExtensionApprovalAction,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin approve/reject a pending cancellation request."""
    log_step(logger, "Approving cancellation", user_id=current_user.id, event_id=event_id, action=body.action)
    event = await event_service.get_or_404(db, event_id)
    if not event.pending_cancellation:
        logger.warning("Approve cancellation rejected: no pending cancellation", extra={"event_id": event_id})
        raise HTTPException(status_code=400, detail="No pending cancellation for this event")
    if body.action == "approve":
        event = await event_service.approve_cancellation(db, event)
    elif body.action == "reject":
        event = await event_service.reject_cancellation(db, event)
    else:
        logger.warning("Approve cancellation rejected: invalid action", extra={"event_id": event_id, "action": body.action})
        raise HTTPException(status_code=400, detail="action must be 'approve' or 'reject'")
    await _invalidate_event_cache(event_id)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)
