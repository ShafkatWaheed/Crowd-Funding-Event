"""
Venue CRUD. Organizers own venues; customers see all.
"""
from typing import Sequence

from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.venue import Venue
from app.core.exceptions import NotFoundError, ConflictError
from app.repositories.venue_repo import venue_repo
from app.repositories.event_repo import event_repo

logger = get_logger("svc.venue")


async def list_venues(
    db: AsyncSession,
    *,
    city: str | None = None,
    organizer_id: int | None = None,
) -> Sequence[Venue]:
    """List venues. If organizer_id given, only that organizer's venues; else all (for customers)."""
    return await venue_repo.list_venues(db, city=city, organizer_id=organizer_id)


async def get_by_id(db: AsyncSession, venue_id: int) -> Venue | None:
    """Get venue by id or None."""
    return await venue_repo.get_by_id(db, venue_id)


async def get_or_404(db: AsyncSession, venue_id: int) -> Venue:
    venue = await venue_repo.get_by_id(db, venue_id)
    if not venue:
        raise NotFoundError("Venue", venue_id)
    return venue


def can_edit_venue(organizer_id: int, venue: Venue, is_admin: bool) -> bool:
    """True if user can edit/delete this venue (owner or admin)."""
    return is_admin or venue.organizer_id == organizer_id


async def create(
    db: AsyncSession,
    *,
    organizer_id: int,
    name: str,
    address: str,
    city: str,
    province: str | None,
    lat: float | None,
    lng: float | None,
    max_capacity: int,
) -> Venue:
    log_step(logger, "Create venue", organizer_id=organizer_id, venue_name=name, max_capacity=max_capacity)
    if max_capacity <= 0:
        logger.warning("Create venue rejected: invalid capacity", extra={"max_capacity": max_capacity})
        raise ConflictError("max_capacity must be greater than 0")
    venue = Venue(
        organizer_id=organizer_id,
        name=name,
        address=address,
        city=city,
        province=province,
        lat=lat,
        lng=lng,
        max_capacity=max_capacity,
    )
    venue = await venue_repo.create_venue(db, venue)
    logger.info("Venue created", extra={"venue_id": venue.id})
    return venue


async def update(
    db: AsyncSession,
    venue: Venue,
    *,
    name: str | None = None,
    address: str | None = None,
    city: str | None = None,
    province: str | None = None,
    lat: float | None = None,
    lng: float | None = None,
    max_capacity: int | None = None,
) -> Venue:
    log_step(logger, "Update venue", venue_id=venue.id)
    if max_capacity is not None and max_capacity <= 0:
        logger.warning("Update venue rejected: invalid capacity", extra={"venue_id": venue.id, "max_capacity": max_capacity})
        raise ConflictError("max_capacity must be greater than 0")
    if name is not None:
        venue.name = name
    if address is not None:
        venue.address = address
    if city is not None:
        venue.city = city
    if province is not None:
        venue.province = province
    if lat is not None:
        venue.lat = lat
    if lng is not None:
        venue.lng = lng
    if max_capacity is not None:
        venue.max_capacity = max_capacity
    venue = await venue_repo.update_venue(db, venue)
    logger.info("Venue updated", extra={"venue_id": venue.id})
    return venue


async def prepare_venue_deletion(db: AsyncSession, venue_id: int) -> None:
    """Ensure completed/cancelled events have venue snapshots, then nullify their venue_id.

    Safety net: if any terminal event somehow missed its snapshot during
    status transition, we backfill it here before unlinking.
    """
    from app.services.event.crud import _snapshot_venue

    terminal_events = await event_repo.get_terminal_events_for_venue(db, venue_id)
    for ev in terminal_events:
        await _snapshot_venue(db, ev)
    await venue_repo.nullify_venue_on_terminal_events(db, venue_id)
