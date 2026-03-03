"""
Venue data-access layer.

All SQLAlchemy queries for venues live here. Services must call these methods
instead of db.execute() directly.
"""
from typing import Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event
from app.models.venue import Venue
from app.repositories.base import BaseRepository


class VenueRepository(BaseRepository[Venue]):
    model_class = Venue

    async def list_venues(
        self,
        db: AsyncSession,
        *,
        city: str | None = None,
        organizer_id: int | None = None,
    ) -> Sequence[Venue]:
        """List venues with optional city / organizer filters, ordered by name."""
        q = select(Venue)
        if organizer_id is not None:
            q = q.where(Venue.organizer_id == organizer_id)
        if city:
            q = q.where(Venue.city == city)
        q = q.order_by(Venue.name.asc())
        result = await db.execute(q)
        return result.scalars().all()

    async def get_by_id(self, db: AsyncSession, venue_id: int) -> Venue | None:
        """Get venue by id or None."""
        result = await db.execute(select(Venue).where(Venue.id == venue_id))
        return result.scalar_one_or_none()

    async def create_venue(self, db: AsyncSession, venue: Venue) -> Venue:
        """Add a new venue, flush, and refresh."""
        db.add(venue)
        await db.flush()
        await db.refresh(venue)
        return venue

    async def update_venue(self, db: AsyncSession, venue: Venue) -> Venue:
        """Flush pending attribute changes and refresh from database."""
        await db.flush()
        await db.refresh(venue)
        return venue

    async def delete_venue(self, db: AsyncSession, venue: Venue) -> None:
        """Hard-delete a venue row."""
        await db.delete(venue)
        await db.flush()

    async def count_events_for_venue(self, db: AsyncSession, venue_id: int) -> int:
        """Count events linked to a venue."""
        result = await db.execute(
            select(func.count()).select_from(Event).where(Event.venue_id == venue_id)
        )
        return int(result.scalar_one())

    async def list_distinct_cities(self, db: AsyncSession) -> list[str]:
        """Return sorted list of distinct non-empty venue cities."""
        q = (
            select(Venue.city)
            .where(Venue.city.isnot(None), Venue.city != "")
            .distinct()
            .order_by(Venue.city)
        )
        return list((await db.execute(q)).scalars().all())


# Module-level singleton
venue_repo = VenueRepository()
