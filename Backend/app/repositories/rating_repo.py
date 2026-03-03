"""
Rating data-access layer.

All SQLAlchemy queries for ratings live here.
"""
from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.rating import Rating, RatingDirection


class RatingRepository:
    """Pure data-access for Rating."""

    # ── Single-row lookups ──────────────────────────────────────────

    async def get_existing(
        self,
        db: AsyncSession,
        rater_user_id: int,
        event_id: int,
        direction: RatingDirection,
    ) -> Rating | None:
        """Check if a user has already submitted a rating for this event/direction."""
        q = select(Rating).where(
            Rating.rater_user_id == rater_user_id,
            Rating.event_id == event_id,
            Rating.direction == direction,
        )
        return (await db.execute(q)).scalar_one_or_none()

    # ── Create ──────────────────────────────────────────────────────

    async def create(self, db: AsyncSession, rating: Rating) -> Rating:
        db.add(rating)
        await db.flush()
        return rating

    # ── Event-scoped queries ────────────────────────────────────────

    async def get_event_aggregate(
        self,
        db: AsyncSession,
        event_id: int,
        direction: RatingDirection,
    ) -> tuple[float | None, int]:
        """Return (avg_stars, count) for an event + direction."""
        q = select(
            func.avg(Rating.stars).label("avg_stars"),
            func.count(Rating.id).label("count"),
        ).where(
            Rating.event_id == event_id,
            Rating.direction == direction,
        )
        row = (await db.execute(q)).one()
        avg = round(float(row.avg_stars), 1) if row.avg_stars else None
        return avg, int(row.count)

    async def list_event_top(
        self,
        db: AsyncSession,
        event_id: int,
        direction: RatingDirection,
        *,
        best: bool = True,
        limit: int = 5,
    ) -> list[Rating]:
        """Top (best or worst) ratings for an event + direction, with rater loaded."""
        order = Rating.stars.desc() if best else Rating.stars.asc()
        q = (
            select(Rating)
            .where(Rating.event_id == event_id, Rating.direction == direction)
            .options(selectinload(Rating.rater))
            .order_by(order, Rating.created_at.desc())
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().all())

    async def list_by_event(
        self,
        db: AsyncSession,
        event_id: int,
        *,
        direction: RatingDirection | None = None,
    ) -> list[Rating]:
        """All ratings for an event, with rater loaded."""
        q = (
            select(Rating)
            .where(Rating.event_id == event_id)
            .options(selectinload(Rating.rater))
        )
        if direction is not None:
            q = q.where(Rating.direction == direction)
        q = q.order_by(Rating.created_at.desc())
        return list((await db.execute(q)).scalars().all())

    # ── User-scoped queries ─────────────────────────────────────────

    async def get_user_aggregate(
        self, db: AsyncSession, rated_user_id: int
    ) -> tuple[float | None, int]:
        """Return (avg_stars, count) for ratings received by a user."""
        q = select(
            func.avg(Rating.stars).label("avg_stars"),
            func.count(Rating.id).label("count"),
        ).where(Rating.rated_user_id == rated_user_id)
        row = (await db.execute(q)).one()
        avg = round(float(row.avg_stars), 1) if row.avg_stars else None
        return avg, int(row.count)

    async def list_user_top(
        self,
        db: AsyncSession,
        rated_user_id: int,
        *,
        best: bool = True,
        limit: int = 5,
    ) -> list[Rating]:
        """Top (best or worst) ratings received by a user, with rater loaded."""
        order = Rating.stars.desc() if best else Rating.stars.asc()
        q = (
            select(Rating)
            .where(Rating.rated_user_id == rated_user_id)
            .options(selectinload(Rating.rater))
            .order_by(order, Rating.created_at.desc())
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().all())


# Module-level singleton
rating_repo = RatingRepository()
