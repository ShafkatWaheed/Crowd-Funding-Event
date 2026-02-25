"""
Event lifecycle: cancel, extend-funding, set-event-date, start-selling, reactivate, publish, clone, extension-decision, cancellation/approve.
"""
from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import DbSession, require_role
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

from ._helpers import _event_to_response, _parse_iso_datetime

router = APIRouter()


@router.post("/{event_id}/cancel", response_model=EventResponse)
async def cancel_event(
    event_id: int,
    body: CancelBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Organizer (main or co-) cancels the event. A reason is required."""
    from sqlalchemy import select as sel
    from app.models.registration import Registration, RegistrationStatus
    from app.models.funding import Funding, FundingStatus

    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot cancel this event")
    event = await event_service.cancel_event(db, event, current_user, reason=body.reason)
    await arq_enqueue(
        "send_event_cancelled_email",
        event.id,
        event.title or f"Event #{event.id}",
        body.reason,
        event.start_time,
    )
    affected_q = sel(Registration.user_id).where(
        Registration.event_id == event.id,
        Registration.status.in_([RegistrationStatus.registered, RegistrationStatus.waitlist]),
    )
    affected_ids = [r for r in (await db.execute(affected_q)).scalars().all()]
    pledger_q = sel(Funding.user_id).where(
        Funding.event_id == event.id,
        Funding.status.in_([FundingStatus.pledged, FundingStatus.refunded]),
    )
    pledger_ids = [r for r in (await db.execute(pledger_q)).scalars().all()]
    all_ids = list(set(affected_ids + pledger_ids))
    if all_ids:
        await notif_svc.create_bulk_notifications(
            db, user_ids=all_ids,
            type=NotificationType.event_cancelled,
            title="Event Cancelled",
            message=f'"{event.title}" has been cancelled. {body.reason or ""}',
            data={"event_id": event.id},
        )
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
    event = await event_service.get_or_404(db, event_id)
    if not any([body.funding_end_at, body.funding_goal_cents]):
        raise HTTPException(status_code=400, detail="At least one of funding_end_at or funding_goal_cents required")
    new_funding_end_at = _parse_iso_datetime(body.funding_end_at)
    event = await event_service.extend_funding(
        db, event, current_user,
        new_funding_end_at=new_funding_end_at,
        new_funding_goal_cents=body.funding_goal_cents,
    )
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/set-event-date", response_model=EventResponse)
async def set_event_date_endpoint(
    event_id: int,
    body: SetEventDateBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Set or update event start/end time."""
    event = await event_service.get_or_404(db, event_id)
    new_start = _parse_iso_datetime(body.start_time)
    new_end = _parse_iso_datetime(body.end_time)
    if new_start is None or new_end is None:
        raise HTTPException(status_code=400, detail="Both start_time and end_time are required as valid ISO datetimes")
    event = await event_service.set_event_date(
        db, event, current_user,
        new_start_time=new_start,
        new_end_time=new_end,
    )
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/start-selling", response_model=EventResponse)
async def start_selling_tickets_endpoint(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Manually transition event to selling_tickets."""
    event = await event_service.get_or_404(db, event_id)
    event = await event_service.start_selling_tickets(db, event, current_user)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/reactivate", response_model=EventResponse)
async def reactivate_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Move a cancelled event back to draft."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot reactivate this event")
    event = await event_service.reactivate_event(db, event, current_user)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/publish", response_model=EventResponse)
async def publish_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Publish a draft event (draft → approved)."""
    event = await event_service.publish_event(db, event_id=event_id, user=current_user)
    await notif_svc.create_notification(
        db, user_id=current_user.id,
        type=NotificationType.event_approved,
        title="Event Published",
        message=f'Your event "{event.title}" is now live.',
        data={"event_id": event.id},
    )
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/clone", response_model=EventResponse)
async def clone_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Clone a completed event into a new draft."""
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
    event = await event_service.get_or_404(db, event_id)
    if body.action == "approve":
        event = await event_service.approve_extension(db, event, current_user)
    elif body.action == "reject":
        event = await event_service.reject_extension(db, event, current_user)
    else:
        raise HTTPException(status_code=400, detail="action must be 'approve' or 'reject'")
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/cancellation/approve", response_model=EventResponse)
async def approve_cancellation(
    event_id: int,
    body: ExtensionApprovalAction,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin approve/reject a pending cancellation request."""
    event = await event_service.get_or_404(db, event_id)
    if not event.pending_cancellation:
        raise HTTPException(status_code=400, detail="No pending cancellation for this event")
    if body.action == "approve":
        reason = event.pending_cancellation.get("reason", "Admin-approved cancellation")
        event.pending_cancellation = None
        event.status = EventStatus.cancelled
        event.cancellation_reason = reason
        await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
        await sponsor_service.refund_all_sponsor_payments_for_event(db, event_id=event.id)
        await ticket_service.refund_all_tickets_for_event(db, event_id=event.id)
        await db.flush()
        await arq_enqueue(
            "send_event_cancelled_email",
            event.id,
            event.title or f"Event #{event.id}",
            reason,
            event.start_time,
        )
    elif body.action == "reject":
        event.pending_cancellation = None
        await db.flush()
    else:
        raise HTTPException(status_code=400, detail="action must be 'approve' or 'reject'")
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)
