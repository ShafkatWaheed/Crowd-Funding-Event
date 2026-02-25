"""
Event co-organizers: list, add, remove (main organizer only).
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import EventOrganizer
from app.models.user import User
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError

from app.services.event.crud import get_by_id, get_or_404
from app.services.event.permissions import is_main_organizer


async def list_event_organizers(db: AsyncSession, *, event_id: int) -> tuple[User, list[EventOrganizer]]:
    """
    Return (main_organizer, [co_organizers]) for the event.
    Main organizer is event.organizer; co-organizers are from event_organizers table.
    """
    event = await get_by_id(db, event_id, load_organizer=True)
    if not event:
        raise NotFoundError("Event", event_id)
    main = event.organizer
    q = (
        select(EventOrganizer)
        .where(EventOrganizer.event_id == event_id)
        .options(selectinload(EventOrganizer.user))
        .order_by(EventOrganizer.created_at.asc())
    )
    result = await db.execute(q)
    co_organizers = list(result.scalars().unique().all())
    return main, co_organizers


async def add_event_organizer(
    db: AsyncSession, *, event_id: int, user_id: int, added_by: User, permission: str = "read"
) -> EventOrganizer:
    """Main organizer adds a co-organizer. User must have role organizer."""
    event = await get_or_404(db, event_id)
    if not is_main_organizer(added_by, event):
        raise ForbiddenError("Only the main organizer can add co-organizers")
    if user_id == event.organizer_id:
        raise ConflictError("User is already the main organizer")
    if permission not in ("read", "full"):
        raise ConflictError("Permission must be 'read' or 'full'")
    # Load user to check role
    target = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not target:
        raise NotFoundError("User", user_id)
    if target.role.value != "organizer":
        raise ConflictError("Only users with organizer role can be added as co-organizers")
    existing = (
        await db.execute(
            select(EventOrganizer).where(
                EventOrganizer.event_id == event_id,
                EventOrganizer.user_id == user_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        raise ConflictError("User is already a co-organizer for this event")
    eo = EventOrganizer(event_id=event_id, user_id=user_id, permission=permission)
    db.add(eo)
    await db.flush()
    await db.refresh(eo)
    return eo


async def remove_event_organizer(db: AsyncSession, *, event_id: int, user_id: int, removed_by: User) -> None:
    """Main organizer removes a co-organizer. Cannot remove main organizer."""
    event = await get_or_404(db, event_id)
    if not is_main_organizer(removed_by, event):
        raise ForbiddenError("Only the main organizer can remove co-organizers")
    if user_id == event.organizer_id:
        raise ConflictError("Cannot remove the main organizer")
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event_id,
        EventOrganizer.user_id == user_id,
    )
    result = await db.execute(q)
    eo = result.scalar_one_or_none()
    if not eo:
        raise NotFoundError("Co-organizer", user_id)
    await db.delete(eo)
    await db.flush()


# ═══════════════════════════════════════════
# Event Discounts
# ═══════════════════════════════════════════

