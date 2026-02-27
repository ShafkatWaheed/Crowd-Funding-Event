"""
Event permission checks: who can edit, read mgmt, scan tickets, main organizer.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventOrganizer
from app.models.user import User


def _event_can_edit(user: User, event: Event) -> bool:
    """Main organizer or admin (sync check, no co-organizers)."""
    return user.role.value == "admin" or event.organizer_id == user.id


async def user_can_edit_event(db: AsyncSession, event: Event, user: User) -> bool:
    """True if user is admin, main organizer, or accepted co-organizer with 'full' permission."""
    if user.role.value == "admin" or event.organizer_id == user.id:
        return True
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event.id,
        EventOrganizer.user_id == user.id,
        EventOrganizer.invitation_status == "accepted",
    )
    result = await db.execute(q)
    eo = result.scalar_one_or_none()
    return eo is not None and eo.permission == "full"


async def user_can_read_event_mgmt(db: AsyncSession, event: Event, user: User) -> bool:
    """True if user is admin, main organizer, or ANY accepted co-organizer (read or full)."""
    if user.role.value == "admin" or event.organizer_id == user.id:
        return True
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event.id,
        EventOrganizer.user_id == user.id,
        EventOrganizer.invitation_status == "accepted",
    )
    result = await db.execute(q)
    return result.scalar_one_or_none() is not None


async def user_can_scan_tickets(db: AsyncSession, event: Event, user: User) -> bool:
    """True if user is admin, main organizer, or ANY accepted co-organizer (read or full).

    Ticket scanning is a write operation but read co-organizers are explicitly allowed.
    """
    return await user_can_read_event_mgmt(db, event, user)


async def get_co_organizer_role(db: AsyncSession, event: Event, user: User) -> str | None:
    """Return the accepted co-organizer permission ('read' or 'full') or None."""
    if user.role.value == "admin" or event.organizer_id == user.id:
        return None
    q = select(EventOrganizer).where(
        EventOrganizer.event_id == event.id,
        EventOrganizer.user_id == user.id,
        EventOrganizer.invitation_status == "accepted",
    )
    result = await db.execute(q)
    eo = result.scalar_one_or_none()
    return eo.permission if eo else None


def is_main_organizer(user: User, event: Event) -> bool:
    """True if user is the main organizer (owner) or admin."""
    return user.role.value == "admin" or event.organizer_id == user.id
