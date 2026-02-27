"""
Event co-organizers: list, invite, update permission, respond, self-remove, remove.
"""
from fastapi import APIRouter, Depends

from app.dependencies import DbSession, ReadDbSession, require_role
from app.logger import get_logger, log_step
from app.models.user import User, UserRole
from app.schemas import (
    AddEventOrganizerBody,
    EventOrganizerItem,
    RespondToInvitationBody,
    UpdateOrganizerPermissionBody,
)
from app.core.exceptions import ForbiddenError
from app.services import event as event_service

router = APIRouter()
logger = get_logger("api.events.organizers")


@router.get("/{event_id}/organizers", response_model=list[EventOrganizerItem])
async def list_event_organizers(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List main + co-organizers for the event."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_read_event_mgmt(db, event, current_user):
        raise ForbiddenError("You cannot view organizers for this event")
    main, co_organizers = await event_service.list_event_organizers(db, event_id=event_id)
    out = [
        EventOrganizerItem(
            user_id=main.id,
            display_name=main.display_name,
            email=main.email,
            is_main=True,
            permission="full",
            invitation_status="accepted",
        ),
    ]
    for eo in co_organizers:
        u = eo.user
        out.append(
            EventOrganizerItem(
                user_id=u.id,
                display_name=u.display_name,
                email=u.email,
                is_main=False,
                permission=eo.permission,
                invitation_status=eo.invitation_status,
            ),
        )
    return out


@router.post("/{event_id}/organizers")
async def add_event_organizer(
    event_id: int,
    body: AddEventOrganizerBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Invite a co-organizer (main organizer only). Creates with pending status."""
    log_step(logger, "Adding co-organizer", user_id=current_user.id, event_id=event_id, invitee_user_id=body.user_id)
    eo = await event_service.add_event_organizer(
        db, event_id=event_id, user_id=body.user_id,
        added_by=current_user, permission=body.permission,
    )
    return {
        "id": eo.id, "event_id": eo.event_id, "user_id": eo.user_id,
        "permission": eo.permission, "invitation_status": eo.invitation_status,
    }


@router.patch("/{event_id}/organizers/{user_id}")
async def update_organizer_permission(
    event_id: int,
    user_id: int,
    body: UpdateOrganizerPermissionBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update a co-organizer's permission (main organizer only)."""
    log_step(logger, "Updating co-organizer permission", user_id=current_user.id, event_id=event_id, target_user_id=user_id)
    eo = await event_service.update_event_organizer_permission(
        db, event_id=event_id, user_id=user_id,
        updated_by=current_user, permission=body.permission,
    )
    return {
        "id": eo.id, "event_id": eo.event_id, "user_id": eo.user_id,
        "permission": eo.permission, "invitation_status": eo.invitation_status,
    }


@router.post("/{event_id}/organizers/{user_id}/respond")
async def respond_to_invitation(
    event_id: int,
    user_id: int,
    body: RespondToInvitationBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Accept or decline a co-organizer invitation (invited user only)."""
    log_step(logger, "Responding to invitation", user_id=current_user.id, event_id=event_id, target_user_id=user_id, accept=body.accept)
    if current_user.id != user_id and current_user.role != UserRole.admin:
        logger.warning("Respond to invitation rejected: not own invitation", extra={"user_id": current_user.id, "event_id": event_id})
        raise ForbiddenError("You can only respond to your own invitations")
    eo = await event_service.respond_to_invitation(
        db, event_id=event_id, user=current_user, accept=body.accept,
    )
    return {
        "id": eo.id, "event_id": eo.event_id, "user_id": eo.user_id,
        "permission": eo.permission, "invitation_status": eo.invitation_status,
    }


@router.delete("/{event_id}/organizers/me")
async def self_remove_from_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Co-organizer removes themselves from the event."""
    log_step(logger, "Self-removing from event", user_id=current_user.id, event_id=event_id)
    await event_service.self_remove_from_event(
        db, event_id=event_id, user=current_user,
    )
    return {"ok": True}


@router.delete("/{event_id}/organizers/{user_id}")
async def remove_event_organizer(
    event_id: int,
    user_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Remove a co-organizer (main organizer only)."""
    log_step(logger, "Removing co-organizer", user_id=current_user.id, event_id=event_id, target_user_id=user_id)
    await event_service.remove_event_organizer(
        db, event_id=event_id, user_id=user_id, removed_by=current_user,
    )
    return {"ok": True}
