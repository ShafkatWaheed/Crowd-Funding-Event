"""
Venue CRUD and simple listing.
"""
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.venue import Venue
from app.core.exceptions import NotFoundError, ConflictError


async def list_venues(db: AsyncSession, *, city: str | None = None) -> Sequence[Venue]:
    """List venues, optionally filtered by city."""
    q = select(Venue)
    if city:
        q = q.where(Venue.city == city)
    q = q.order_by(Venue.name.asc())
    result = await db.execute(q)
    return result.scalars().all()


async def get_by_id(db: AsyncSession, venue_id: int) -> Venue | None:
    """Get venue by id or None."""
    result = await db.execute(select(Venue).where(Venue.id == venue_id))
    return result.scalar_one_or_none()


async def get_or_404(db: AsyncSession, venue_id: int) -> Venue:
    venue = await get_by_id(db, venue_id)
    if not venue:
        raise NotFoundError("Venue", venue_id)
    return venue


async def create(
    db: AsyncSession,
    *,
    name: str,
    address: str,
    city: str,
    province: str | None,
    lat: float | None,
    lng: float | None,
    max_capacity: int,
) -> Venue:
    if max_capacity <= 0:
        raise ConflictError("max_capacity must be greater than 0")
    venue = Venue(
        name=name,
        address=address,
        city=city,
        province=province,
        lat=lat,
        lng=lng,
        max_capacity=max_capacity,
    )
    db.add(venue)
    await db.flush()
    await db.refresh(venue)
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
    if max_capacity is not None and max_capacity <= 0:
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
    await db.flush()
    await db.refresh(venue)
    return venue
