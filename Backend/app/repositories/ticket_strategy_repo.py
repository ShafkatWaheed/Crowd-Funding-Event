"""
Ticket strategy data-access layer.

All SQLAlchemy queries for ticket strategies and their tiers live here.
"""
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.ticket_strategy import TicketStrategy, TicketStrategyTier
from app.repositories.base import BaseRepository


class TicketStrategyRepository(BaseRepository[TicketStrategy]):
    model_class = TicketStrategy

    async def list_by_organizer(
        self, db: AsyncSession, organizer_id: int
    ) -> Sequence[TicketStrategy]:
        q = (
            select(TicketStrategy)
            .where(TicketStrategy.organizer_id == organizer_id)
            .options(selectinload(TicketStrategy.tiers))
            .order_by(TicketStrategy.updated_at.desc())
        )
        return (await db.execute(q)).scalars().unique().all()

    async def get_with_tiers(
        self, db: AsyncSession, strategy_id: int
    ) -> TicketStrategy | None:
        q = (
            select(TicketStrategy)
            .where(TicketStrategy.id == strategy_id)
            .options(selectinload(TicketStrategy.tiers))
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def get_with_tiers_or_404(
        self, db: AsyncSession, strategy_id: int
    ) -> TicketStrategy:
        s = await self.get_with_tiers(db, strategy_id)
        if not s:
            from app.core.exceptions import NotFoundError
            raise NotFoundError("TicketStrategy", strategy_id)
        return s

    async def create_with_tiers(
        self, db: AsyncSession, strategy: TicketStrategy, tiers: list[dict]
    ) -> TicketStrategy:
        db.add(strategy)
        await db.flush()
        for i, t in enumerate(tiers):
            tier = TicketStrategyTier(
                strategy_id=strategy.id,
                name=t["name"],
                description=t.get("description"),
                price_cents=t["price_cents"],
                display_order=t.get("display_order", i),
            )
            db.add(tier)
        await db.flush()
        await db.refresh(strategy)
        return await self.get_with_tiers_or_404(db, strategy.id)

    async def replace_tiers(
        self, db: AsyncSession, strategy: TicketStrategy, tiers: list[dict]
    ) -> None:
        for existing in list(strategy.tiers):
            await db.delete(existing)
        await db.flush()
        for i, t in enumerate(tiers):
            tier = TicketStrategyTier(
                strategy_id=strategy.id,
                name=t["name"],
                description=t.get("description"),
                price_cents=t["price_cents"],
                display_order=t.get("display_order", i),
            )
            db.add(tier)
        await db.flush()

    async def flush(self, db: AsyncSession) -> None:
        await db.flush()

    async def delete_strategy(
        self, db: AsyncSession, strategy: TicketStrategy
    ) -> None:
        await db.delete(strategy)
        await db.flush()

    async def add_event_tiers(
        self, db: AsyncSession, event_id: int, strategy_tiers: list
    ) -> None:
        from app.models.ticket import TicketTier
        for st in strategy_tiers:
            tier = TicketTier(
                event_id=event_id,
                name=st.name,
                description=st.description,
                price_cents=st.price_cents,
                display_order=st.display_order,
            )
            db.add(tier)
        await db.flush()


ticket_strategy_repo = TicketStrategyRepository()
