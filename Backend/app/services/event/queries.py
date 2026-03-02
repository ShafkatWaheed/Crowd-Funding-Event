"""
Event queries: get_my_registered_events, get_co_organized_events,
get_trending, get_coming_soon, get_popular, clone_event.
"""
from typing import Sequence

from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.event import Event, EventStatus
from app.models.user import User
from app.core.exceptions import ForbiddenError, ConflictError
from app.repositories.event_repo import event_repo

from app.services.event.permissions import user_can_edit_event

logger = get_logger("svc.event.queries")


async def get_my_registered_events(
    db: AsyncSession, *, user_id: int, offset: int = 0, limit: int | None = None,
    sort_by: str = "newest",
) -> Sequence[Event]:
    """Events the user is registered to (any registration status). Useful for 'My Events'."""
    logger.debug("get_my_registered_events", extra={"user_id": user_id, "offset": offset, "limit": limit})
    return await event_repo.list_registered_events(
        db, user_id, offset=offset, limit=limit, sort_by=sort_by,
    )


async def get_trending_events(db: AsyncSession, *, limit: int = 10, sponsorship_only: bool = False) -> Sequence[Event]:
    """Events ordered by registration_count DESC. Public-visible statuses."""
    logger.debug("get_trending_events", extra={"limit": limit, "sponsorship_only": sponsorship_only})
    return await event_repo.list_trending_events(db, limit=limit, sponsorship_only=sponsorship_only)


async def get_coming_soon_events(db: AsyncSession, *, limit: int = 10, sponsorship_only: bool = False) -> Sequence[Event]:
    """Approved events starting in the future, ordered by start_time ASC."""
    logger.debug("get_coming_soon_events", extra={"limit": limit, "sponsorship_only": sponsorship_only})
    return await event_repo.list_coming_soon_events(db, limit=limit, sponsorship_only=sponsorship_only)


async def get_popular_events(db: AsyncSession, *, limit: int = 10, sponsorship_only: bool = False) -> Sequence[Event]:
    """Events with most pledged amount. Public-visible statuses."""
    logger.debug("get_popular_events", extra={"limit": limit, "sponsorship_only": sponsorship_only})
    return await event_repo.list_popular_events(db, limit=limit, sponsorship_only=sponsorship_only)


async def clone_event(db: AsyncSession, event: Event, user: User) -> Event:
    """
    Clone a completed event into a new draft. Copies all params except
    start_time, end_time, funding_end_at (those must be set fresh).
    """
    log_step(logger, "Clone event", event_id=event.id, user_id=user.id)
    if event.status != EventStatus.completed:
        raise ConflictError("Only completed events can be cloned")
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot clone this event")
    return await event_repo.clone_event(db, event)


async def get_co_organized_events(
    db: AsyncSession,
    *,
    user_id: int,
    status: str | None = None,
    search: str | None = None,
    offset: int = 0,
    limit: int = 20,
) -> Sequence[Event]:
    """Events where the user is an accepted co-organizer."""
    logger.debug("get_co_organized_events", extra={"user_id": user_id, "status": status, "search": search, "offset": offset, "limit": limit})
    return await event_repo.list_co_organized_events(
        db, user_id, status=status, search=search, offset=offset, limit=limit,
    )


# ----- Event co-organizers (main organizer only can add/remove) -----
