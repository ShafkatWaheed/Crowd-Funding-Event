"""
Venue data-access layer.

All SQLAlchemy queries for venues live here. Services must call these methods
instead of db.execute() directly.
"""
from typing import Sequence

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventStatus
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

    async def count_active_events_for_venue(self, db: AsyncSession, venue_id: int) -> int:
        """Count events in non-terminal statuses (excludes completed/cancelled)."""
        terminal = [EventStatus.completed, EventStatus.cancelled]
        result = await db.execute(
            select(func.count())
            .select_from(Event)
            .where(Event.venue_id == venue_id, Event.status.not_in(terminal))
        )
        return int(result.scalar_one())

    async def nullify_venue_on_terminal_events(self, db: AsyncSession, venue_id: int) -> None:
        """Set venue_id=NULL on completed/cancelled events (they have snapshots)."""
        terminal = [EventStatus.completed, EventStatus.cancelled]
        await db.execute(
            update(Event)
            .where(Event.venue_id == venue_id, Event.status.in_(terminal))
            .values(venue_id=None)
        )
        await db.flush()

    async def bulk_snapshot_terminal_events(self, db: AsyncSession, venue_id: int) -> None:
        """Bulk-set venue_snapshot on terminal events that don't have one yet.

        Single UPDATE with scalar subquery — no per-row loop, constant query count.
        """
        terminal = [EventStatus.completed, EventStatus.cancelled]
        await db.execute(
            update(Event)
            .where(
                Event.venue_id == venue_id,
                Event.status.in_(terminal),
                Event.venue_snapshot.is_(None),
            )
            .values(
                venue_snapshot=select(
                    func.jsonb_build_object(
                        "id", Venue.id,
                        "name", Venue.name,
                        "address", Venue.address,
                        "city", Venue.city,
                        "province", Venue.province,
                        "lat", Venue.lat,
                        "lng", Venue.lng,
                        "max_capacity", Venue.max_capacity,
                    )
                )
                .where(Venue.id == venue_id)
                .correlate_except(Venue)
                .scalar_subquery()
            )
        )
        await db.flush()

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
