"""
Discount strategy data-access layer.

All SQLAlchemy queries for discount strategies, event-strategy links,
and customer discount claims live here.
"""
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.discount_strategy import (
    CustomerDiscountClaim,
    DiscountStrategy,
    EventDiscountStrategyLink,
)
from app.repositories.base import BaseRepository


class DiscountRepository(BaseRepository[DiscountStrategy]):
    model_class = DiscountStrategy

    # ── Strategy CRUD ────────────────────────────────────────

    async def list_by_organizer(
        self, db: AsyncSession, organizer_id: int
    ) -> Sequence[DiscountStrategy]:
        q = (
            select(DiscountStrategy)
            .where(DiscountStrategy.organizer_id == organizer_id)
            .order_by(DiscountStrategy.created_at.desc())
        )
        return (await db.execute(q)).scalars().all()

    async def update_fields(
        self, db: AsyncSession, strategy: DiscountStrategy, data: dict
    ) -> DiscountStrategy:
        for field, value in data.items():
            setattr(strategy, field, value)
        await db.flush()
        await db.refresh(strategy)
        return strategy

    async def delete_strategy(
        self, db: AsyncSession, strategy: DiscountStrategy
    ) -> None:
        await db.delete(strategy)
        await db.flush()

    # ── Event-Strategy Links ─────────────────────────────────

    async def get_link(
        self, db: AsyncSession, event_id: int, strategy_id: int
    ) -> EventDiscountStrategyLink | None:
        q = select(EventDiscountStrategyLink).where(
            EventDiscountStrategyLink.event_id == event_id,
            EventDiscountStrategyLink.discount_strategy_id == strategy_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def get_link_by_id(
        self, db: AsyncSession, link_id: int
    ) -> EventDiscountStrategyLink | None:
        q = select(EventDiscountStrategyLink).where(
            EventDiscountStrategyLink.id == link_id
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def create_link(
        self, db: AsyncSession, link: EventDiscountStrategyLink
    ) -> EventDiscountStrategyLink:
        db.add(link)
        await db.flush()
        await db.refresh(link)
        return link

    async def delete_link(
        self, db: AsyncSession, link: EventDiscountStrategyLink
    ) -> None:
        await db.delete(link)
        await db.flush()

    async def list_event_links(
        self, db: AsyncSession, event_id: int
    ) -> list[EventDiscountStrategyLink]:
        q = (
            select(EventDiscountStrategyLink)
            .options(selectinload(EventDiscountStrategyLink.strategy))
            .where(EventDiscountStrategyLink.event_id == event_id)
            .order_by(EventDiscountStrategyLink.id)
        )
        return list((await db.execute(q)).scalars().all())

    async def list_claimable_links(
        self, db: AsyncSession, event_id: int
    ) -> list[EventDiscountStrategyLink]:
        q = (
            select(EventDiscountStrategyLink)
            .options(selectinload(EventDiscountStrategyLink.strategy))
            .where(
                EventDiscountStrategyLink.event_id == event_id,
                EventDiscountStrategyLink.auto_apply == False,  # noqa: E712
            )
        )
        return list((await db.execute(q)).scalars().all())

    # ── Customer Claims ──────────────────────────────────────

    async def get_claim(
        self, db: AsyncSession, link_id: int, user_id: int
    ) -> CustomerDiscountClaim | None:
        q = select(CustomerDiscountClaim).where(
            CustomerDiscountClaim.link_id == link_id,
            CustomerDiscountClaim.user_id == user_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def list_claimed_link_ids(
        self, db: AsyncSession, user_id: int, link_ids: list[int]
    ) -> set[int]:
        if not link_ids:
            return set()
        q = select(CustomerDiscountClaim.link_id).where(
            CustomerDiscountClaim.user_id == user_id,
            CustomerDiscountClaim.link_id.in_(link_ids),
        )
        return set((await db.execute(q)).scalars().all())

    async def create_claim(
        self, db: AsyncSession, claim: CustomerDiscountClaim
    ) -> CustomerDiscountClaim:
        db.add(claim)
        await db.flush()
        await db.refresh(claim)
        return claim

    async def delete_claim(
        self, db: AsyncSession, claim: CustomerDiscountClaim
    ) -> None:
        await db.delete(claim)
        await db.flush()

    async def user_has_claimed(
        self, db: AsyncSession, link_id: int, user_id: int
    ) -> bool:
        q = select(CustomerDiscountClaim.id).where(
            CustomerDiscountClaim.link_id == link_id,
            CustomerDiscountClaim.user_id == user_id,
        )
        return (await db.execute(q)).scalar_one_or_none() is not None


discount_repo = DiscountRepository()
