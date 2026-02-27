"""
Event registration: register, unregister, my-registration, registrations list, decision.
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select

from app.dependencies import CurrentUser, DbSession, ReadDbSession, require_role
from app.models.event import EventStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User, UserRole
from app.schemas import RegistrationDecisionBody, RegistrationResponse, UnregisterResponse
from app.core.exceptions import ForbiddenError
from app.services import event as event_service
from app.services import registration as registration_service
from app.services import notification_service as notif_svc
from app.api.v1.events._helpers import safe_display_name
from app.models.notification import NotificationType
from app.rate_limit import limiter, dynamic_limit

router = APIRouter()


@router.post("/{event_id}/register")
@limiter.limit(dynamic_limit("event_register", "20/minute"))
async def register_event(
    request: Request,
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Register for event (open: first-come; closed: request)."""
    reg = await registration_service.register(db, event_id=event_id, user=current_user)
    if reg.status.value == "registered":
        await notif_svc.create_notification(
            db, user_id=current_user.id,
            type=NotificationType.registration_confirmed,
            title="Registration Confirmed",
            message="You are registered for the event.",
            data={"event_id": event_id},
        )
    elif reg.status.value == "waitlist":
        await notif_svc.create_notification(
            db, user_id=current_user.id,
            type=NotificationType.registration_waitlisted,
            title="Added to Waitlist",
            message="You have been added to the waitlist.",
            data={"event_id": event_id},
        )
        event = await event_service.get_or_404(db, event_id)
        await notif_svc.create_notification(
            db, user_id=event.organizer_id,
            type=NotificationType.registration_waitlisted,
            title="New Waitlist Entry",
            message=f"{safe_display_name(current_user)} joined the waitlist for your event.",
            data={"event_id": event_id, "user_id": current_user.id},
        )
    return RegistrationResponse(
        id=reg.id,
        event_id=reg.event_id,
        user_id=reg.user_id,
        status=reg.status.value,
        created_at=reg.created_at,
    )


@router.get("/{event_id}/my-registration")
async def get_my_registration(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin, UserRole.sponsor)),
):
    """Check if the current user is registered for this event."""
    q = select(Registration).where(
        Registration.event_id == event_id,
        Registration.user_id == current_user.id,
    )
    result = await db.execute(q)
    reg = result.scalar_one_or_none()
    if reg:
        is_active = reg.status in (RegistrationStatus.registered, RegistrationStatus.waitlist)
        return {"registered": is_active, "status": reg.status.value}
    return {"registered": False, "status": None}


@router.post("/{event_id}/unregister", response_model=UnregisterResponse)
async def unregister_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Customer unregisters from event."""
    event = await event_service.get_or_404(db, event_id)
    blocked_statuses = (
        EventStatus.selling_tickets, EventStatus.waiting_event_date,
        EventStatus.live, EventStatus.completed,
    )
    if event.status in blocked_statuses:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot unregister — event is in '{event.status.value}' state",
        )
    result = await registration_service.unregister(db, event_id=event_id, user=current_user)
    if result.get("refunded_cents", 0) > 0:
        await notif_svc.create_notification(
            db, user_id=current_user.id,
            type=NotificationType.refund_issued,
            title="Refund Processing",
            message=f"Your pledge refund of ${result['refunded_cents'] / 100:.2f} is being processed.",
            data={"event_id": event_id},
        )
    return UnregisterResponse(
        refunded_cents=result["refunded_cents"],
        pledges_refunded=result["pledges_refunded"],
        refund_eligible=result["refund_eligible"],
    )


@router.get("/{event_id}/registrations")
async def list_registrations(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List registrations for event (organizer/admin/co-organizer)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_read_event_mgmt(db, event, current_user):
        raise ForbiddenError("You cannot view registrations for this event")
    regs = await registration_service.list_registrations(db, event_id=event_id)
    return [
        RegistrationResponse(
            id=r.id,
            event_id=r.event_id,
            user_id=r.user_id,
            status=r.status.value,
            created_at=r.created_at,
        )
        for r in regs
    ]


@router.post("/{event_id}/registrations/{registration_id}/decision", response_model=RegistrationResponse)
async def decide_registration(
    event_id: int,
    registration_id: int,
    body: RegistrationDecisionBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Organizer/admin approves or rejects a waitlist request."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot manage registrations for this event")

    if body.action == "approve":
        reg = await registration_service.approve_waitlist(
            db, event_id=event_id, registration_id=registration_id
        )
    else:
        reg = await registration_service.reject_waitlist(
            db, event_id=event_id, registration_id=registration_id
        )

    return RegistrationResponse(
        id=reg.id,
        event_id=reg.event_id,
        user_id=reg.user_id,
        status=reg.status.value,
        created_at=reg.created_at,
    )
