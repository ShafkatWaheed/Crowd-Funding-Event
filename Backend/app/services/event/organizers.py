"""
Event co-organizers: list, add (invite), remove, update permission, respond, self-remove.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import EventOrganizer
from app.models.notification import NotificationType
from app.models.user import User
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError
from app.repositories.event_repo import event_repo

from app.logger import get_logger
from app.services.event.crud import get_by_id, get_or_404
from app.services.event.permissions import is_main_organizer

logger = get_logger("co_organizers")


async def _notify(db: AsyncSession, user_id: int, type: NotificationType, title: str, message: str, data: dict | None = None):
    from app.services.notification_service import create_notification
    try:
        await create_notification(db, user_id=user_id, type=type, title=title, message=message, data=data)
    except Exception:
        logger.debug("Could not create co-organizer notification for user %d", user_id)


async def list_event_organizers(db: AsyncSession, *, event_id: int) -> tuple[User, list[EventOrganizer]]:
    """
    Return (main_organizer, [co_organizers]) for the event.
    Main organizer is event.organizer; co-organizers are from event_organizers table.
    """
    event = await get_by_id(db, event_id, load_organizer=True)
    if not event:
        raise NotFoundError("Event", event_id)
    main = event.organizer
    co_organizers = await event_repo.list_event_organizers(db, event_id)
    return main, co_organizers


async def add_event_organizer(
    db: AsyncSession, *, event_id: int, user_id: int, added_by: User, permission: str = "read"
) -> EventOrganizer:
    """Main organizer invites a co-organizer. Creates with status=pending and sends notification."""
    event = await get_or_404(db, event_id)
    if not is_main_organizer(added_by, event):
        raise ForbiddenError("Only the main organizer can add co-organizers")
    if user_id == event.organizer_id:
        raise ConflictError("User is already the main organizer")
    if permission not in ("read", "full"):
        raise ConflictError("Permission must be 'read' or 'full'")
    target = await event_repo.get_user_by_id(db, user_id)
    if not target:
        raise NotFoundError("User", user_id)
    if target.role.value != "organizer":
        raise ConflictError("Only users with organizer role can be added as co-organizers")
    existing = await event_repo.get_co_organizer(db, event_id, user_id)
    if existing:
        if existing.invitation_status == "declined":
            existing.invitation_status = "pending"
            existing.permission = permission
            await event_repo.flush_and_refresh_co_organizer(db, existing)
            await _notify(
                db, user_id, NotificationType.co_organizer_invited,
                "Co-Organizer Invitation",
                f"You've been re-invited as a co-organizer for \"{event.title}\".",
                {"event_id": event_id},
            )
            return existing
        raise ConflictError("User is already a co-organizer for this event")
    from app.services.event.crud import get_effective_policy
    policy = await get_effective_policy(db, event)
    max_co = policy.get("max_co_organizers")
    if max_co and max_co > 0:
        co_count = await event_repo.count_co_organizers(db, event_id)
        if co_count >= max_co:
            raise ConflictError(f"Max {max_co} co-organizers per event")

    eo = EventOrganizer(event_id=event_id, user_id=user_id, permission=permission, invitation_status="pending")
    eo = await event_repo.create_co_organizer(db, eo)
    await _notify(
        db, user_id, NotificationType.co_organizer_invited,
        "Co-Organizer Invitation",
        f"You've been invited as a co-organizer for \"{event.title}\".",
        {"event_id": event_id},
    )
    return eo


async def update_event_organizer_permission(
    db: AsyncSession, *, event_id: int, user_id: int, updated_by: User, permission: str
) -> EventOrganizer:
    """Main organizer updates a co-organizer's permission (read <-> full)."""
    event = await get_or_404(db, event_id)
    if not is_main_organizer(updated_by, event):
        raise ForbiddenError("Only the main organizer can update co-organizer permissions")
    if user_id == event.organizer_id:
        raise ConflictError("Cannot update permission for the main organizer")
    if permission not in ("read", "full"):
        raise ConflictError("Permission must be 'read' or 'full'")
    eo = await event_repo.get_co_organizer(db, event_id, user_id)
    if not eo:
        raise NotFoundError("Co-organizer", user_id)
    eo.permission = permission
    await event_repo.flush_and_refresh_co_organizer(db, eo)
    return eo


async def respond_to_invitation(
    db: AsyncSession, *, event_id: int, user: User, accept: bool
) -> EventOrganizer:
    """Invited user accepts or declines a co-organizer invitation."""
    event = await get_or_404(db, event_id)
    eo = await event_repo.get_co_organizer(db, event_id, user.id)
    if not eo:
        raise NotFoundError("Invitation not found")
    if eo.invitation_status != "pending":
        raise ConflictError(f"Invitation already {eo.invitation_status}")
    eo.invitation_status = "accepted" if accept else "declined"
    await event_repo.flush_and_refresh_co_organizer(db, eo)
    display = user.display_name or f"User #{user.id}"
    if accept:
        await _notify(
            db, event.organizer_id, NotificationType.co_organizer_accepted,
            "Invitation Accepted",
            f"{display} accepted your co-organizer invitation for \"{event.title}\".",
            {"event_id": event_id},
        )
    else:
        await _notify(
            db, event.organizer_id, NotificationType.co_organizer_declined,
            "Invitation Declined",
            f"{display} declined your co-organizer invitation for \"{event.title}\".",
            {"event_id": event_id},
        )
    return eo


async def self_remove_from_event(db: AsyncSession, *, event_id: int, user: User) -> None:
    """Co-organizer removes themselves from the event."""
    event = await get_or_404(db, event_id)
    if user.id == event.organizer_id:
        raise ConflictError("Main organizer cannot self-remove; transfer ownership first")
    eo = await event_repo.get_co_organizer(db, event_id, user.id)
    if not eo:
        raise NotFoundError("You are not a co-organizer for this event")
    await event_repo.delete_co_organizer(db, eo)
    display = user.display_name or f"User #{user.id}"
    await _notify(
        db, event.organizer_id, NotificationType.co_organizer_removed,
        "Co-Organizer Left",
        f"{display} has left \"{event.title}\" as co-organizer.",
        {"event_id": event_id},
    )


async def remove_event_organizer(db: AsyncSession, *, event_id: int, user_id: int, removed_by: User) -> None:
    """Main organizer removes a co-organizer. Cannot remove main organizer."""
    event = await get_or_404(db, event_id)
    if not is_main_organizer(removed_by, event):
        raise ForbiddenError("Only the main organizer can remove co-organizers")
    if user_id == event.organizer_id:
        raise ConflictError("Cannot remove the main organizer")
    eo = await event_repo.get_co_organizer(db, event_id, user_id)
    if not eo:
        raise NotFoundError("Co-organizer", user_id)
    await event_repo.delete_co_organizer(db, eo)
    await _notify(
        db, user_id, NotificationType.co_organizer_removed,
        "Removed from Event",
        f"You've been removed as co-organizer from \"{event.title}\".",
        {"event_id": event_id},
    )


# ===================================
# Event Discounts
# ===================================
