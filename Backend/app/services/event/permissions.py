"""
Event permission checks: who can edit, read mgmt, main organizer.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventOrganizer
from app.models.user import User


def _event_can_edit(user: User, event: Event) -> bool:
    """Main organizer or admin (sync check, no co-organizers)."""
    return user.role.value == "admin" or event.organizer_id == user.id


async def user_can_edit_event(db: AsyncSession, event: Event, user: User) -> bool:
    """True if user is admin, main organizer, or co-organizer with 'full' permission."""
    if user.role.value == "admin" or event.organizer_id == user.id:
        return True
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event.id,
        EventOrganizer.user_id == user.id,
    )
    result = await db.execute(q)
    eo = result.scalar_one_or_none()
    return eo is not None and eo.permission == "full"


async def user_can_read_event_mgmt(db: AsyncSession, event: Event, user: User) -> bool:
    """True if user is admin, main organizer, or ANY co-organizer (read or full)."""
    if user.role.value == "admin" or event.organizer_id == user.id:
        return True
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event.id,
        EventOrganizer.user_id == user.id,
    )
    result = await db.execute(q)
    return result.scalar_one_or_none() is not None


def is_main_organizer(user: User, event: Event) -> bool:
    """True if user is the main organizer (owner) or admin."""
    return user.role.value == "admin" or event.organizer_id == user.id
