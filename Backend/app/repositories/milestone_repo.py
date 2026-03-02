"""
Milestone data-access layer.

All SQLAlchemy queries for funding milestones, milestone reactions,
milestone snapshots, and early bird discounts live here.
"""
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.milestone import (
    EarlyBirdDiscount,
    FundingMilestone,
    FundingMilestoneSnapshot,
    FundingMilestoneUser,
    MilestoneReaction,
)
from app.repositories.base import BaseRepository


class MilestoneRepository(BaseRepository[FundingMilestone]):
    model_class = FundingMilestone

    # ── Milestone CRUD ───────────────────────────────────────

    async def list_by_event(
        self, db: AsyncSession, event_id: int
    ) -> list[FundingMilestone]:
        q = (
            select(FundingMilestone)
            .where(FundingMilestone.event_id == event_id)
            .order_by(FundingMilestone.unlock_percent, FundingMilestone.sort_order)
        )
        return list((await db.execute(q)).scalars().all())

    async def update_fields(
        self, db: AsyncSession, ms: FundingMilestone, data: dict
    ) -> FundingMilestone:
        for field, value in data.items():
            setattr(ms, field, value)
        await db.flush()
        await db.refresh(ms)
        return ms

    async def delete(self, db: AsyncSession, ms: FundingMilestone) -> None:
        await db.delete(ms)
        await db.flush()

    # ── Reactions ────────────────────────────────────────────

    async def get_reaction(
        self, db: AsyncSession, milestone_id: int, user_id: int
    ) -> MilestoneReaction | None:
        q = select(MilestoneReaction).where(
            MilestoneReaction.milestone_id == milestone_id,
            MilestoneReaction.user_id == user_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def create_reaction(
        self, db: AsyncSession, reaction: MilestoneReaction
    ) -> MilestoneReaction:
        db.add(reaction)
        await db.flush()
        return reaction

    async def delete_reaction(
        self, db: AsyncSession, reaction: MilestoneReaction
    ) -> None:
        await db.delete(reaction)
        await db.flush()

    # ── Snapshots ────────────────────────────────────────────

    async def list_snapshots(
        self, db: AsyncSession, event_id: int
    ) -> list[FundingMilestoneSnapshot]:
        q = (
            select(FundingMilestoneSnapshot)
            .where(FundingMilestoneSnapshot.event_id == event_id)
            .order_by(FundingMilestoneSnapshot.milestone_percent)
        )
        return list((await db.execute(q)).scalars().all())

    async def count_snapshot_users(
        self, db: AsyncSession, snapshot_id: int
    ) -> int:
        q = select(func.count()).where(FundingMilestoneUser.snapshot_id == snapshot_id)
        return int((await db.execute(q)).scalar_one())

    # ── Early Bird Discounts ─────────────────────────────────

    async def list_early_bird_by_event(
        self, db: AsyncSession, event_id: int
    ) -> list[EarlyBirdDiscount]:
        q = select(EarlyBirdDiscount).where(EarlyBirdDiscount.event_id == event_id)
        return list((await db.execute(q)).scalars().all())

    async def get_early_bird(
        self, db: AsyncSession, discount_id: int
    ) -> EarlyBirdDiscount | None:
        q = select(EarlyBirdDiscount).where(EarlyBirdDiscount.id == discount_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def create_early_bird(
        self, db: AsyncSession, eb: EarlyBirdDiscount
    ) -> EarlyBirdDiscount:
        db.add(eb)
        await db.flush()
        await db.refresh(eb)
        return eb

    async def update_early_bird(
        self, db: AsyncSession, eb: EarlyBirdDiscount, data: dict
    ) -> EarlyBirdDiscount:
        for field, value in data.items():
            setattr(eb, field, value)
        await db.flush()
        await db.refresh(eb)
        return eb

    async def delete_early_bird(
        self, db: AsyncSession, eb: EarlyBirdDiscount
    ) -> None:
        await db.delete(eb)
        await db.flush()


milestone_repo = MilestoneRepository()
