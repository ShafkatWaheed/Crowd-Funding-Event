"""
Event co-organizers: list, add, remove.
"""
from fastapi import APIRouter, Depends

from app.dependencies import DbSession, require_role
from app.models.user import User, UserRole
from app.schemas import AddEventOrganizerBody, EventOrganizerItem
from app.core.exceptions import ForbiddenError
from app.services import event as event_service

router = APIRouter()


@router.get("/{event_id}/organizers", response_model=list[EventOrganizerItem])
async def list_event_organizers(
    event_id: int,
    db: DbSession,
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
    """Add a co-organizer (main organizer only)."""
    event = await event_service.get_or_404(db, event_id)
    if not event_service.is_main_organizer(current_user, event):
        raise ForbiddenError("Only the main organizer can add co-organizers")
    eo = await event_service.add_event_organizer(
        db, event_id=event_id, user_id=body.user_id,
        added_by=current_user, permission=body.permission,
    )
    return {"id": eo.id, "event_id": eo.event_id, "user_id": eo.user_id, "permission": eo.permission}


@router.delete("/{event_id}/organizers/{user_id}")
async def remove_event_organizer(
    event_id: int,
    user_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Remove a co-organizer (main organizer only)."""
    event = await event_service.get_or_404(db, event_id)
    if not event_service.is_main_organizer(current_user, event):
        raise ForbiddenError("Only the main organizer can remove co-organizers")
    await event_service.remove_event_organizer(db, event_id=event_id, user_id=user_id, removed_by=current_user)
    return {"ok": True}
