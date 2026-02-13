"""
Ticket Strategy CRUD: reusable ticketing templates owned by organizers.
"""
from typing import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.ticket_strategy import TicketStrategy, TicketStrategyTier
from app.models.user import User
from app.core.exceptions import NotFoundError, ForbiddenError


async def list_strategies(db: AsyncSession, *, organizer_id: int) -> Sequence[TicketStrategy]:
    """List ticket strategies owned by this organizer."""
    q = (
        select(TicketStrategy)
        .where(TicketStrategy.organizer_id == organizer_id)
        .options(selectinload(TicketStrategy.tiers))
        .order_by(TicketStrategy.updated_at.desc())
    )
    result = await db.execute(q)
    return result.scalars().unique().all()


async def get_by_id(db: AsyncSession, strategy_id: int) -> TicketStrategy | None:
    q = (
        select(TicketStrategy)
        .where(TicketStrategy.id == strategy_id)
        .options(selectinload(TicketStrategy.tiers))
    )
    result = await db.execute(q)
    return result.scalar_one_or_none()


async def get_or_404(db: AsyncSession, strategy_id: int) -> TicketStrategy:
    s = await get_by_id(db, strategy_id)
    if not s:
        raise NotFoundError("TicketStrategy", strategy_id)
    return s


async def create(
    db: AsyncSession,
    *,
    organizer_id: int,
    name: str,
    tiers: list[dict],
) -> TicketStrategy:
    """Create a ticket strategy with tiers."""
    strategy = TicketStrategy(organizer_id=organizer_id, name=name)
    db.add(strategy)
    await db.flush()
    for i, t in enumerate(tiers):
        tier = TicketStrategyTier(
            strategy_id=strategy.id,
            name=t["name"],
            description=t.get("description"),
            price_cents=t["price_cents"],
            quantity=t.get("quantity", 0),
            display_order=t.get("display_order", i),
        )
        db.add(tier)
    await db.flush()
    await db.refresh(strategy)
    # Reload with tiers
    return await get_or_404(db, strategy.id)


async def update(
    db: AsyncSession,
    strategy: TicketStrategy,
    user: User,
    *,
    name: str | None = None,
    tiers: list[dict] | None = None,
) -> TicketStrategy:
    """Update a ticket strategy. If tiers provided, replaces all tiers."""
    if strategy.organizer_id != user.id and user.role.value != "admin":
        raise ForbiddenError("You can only edit your own ticket strategies")
    if name is not None:
        strategy.name = name
    if tiers is not None:
        # Delete existing tiers
        for existing in list(strategy.tiers):
            await db.delete(existing)
        await db.flush()
        # Add new tiers
        for i, t in enumerate(tiers):
            tier = TicketStrategyTier(
                strategy_id=strategy.id,
                name=t["name"],
                description=t.get("description"),
                price_cents=t["price_cents"],
                quantity=t.get("quantity", 0),
                display_order=t.get("display_order", i),
            )
            db.add(tier)
    await db.flush()
    return await get_or_404(db, strategy.id)


async def delete(db: AsyncSession, strategy: TicketStrategy, user: User) -> None:
    """Delete a ticket strategy (cascade deletes tiers)."""
    if strategy.organizer_id != user.id and user.role.value != "admin":
        raise ForbiddenError("You can only delete your own ticket strategies")
    await db.delete(strategy)
    await db.flush()


async def apply_strategy_to_event(
    db: AsyncSession,
    *,
    strategy_id: int,
    event_id: int,
) -> None:
    """
    Copy tiers from a ticket strategy into TicketTier rows for an event.
    This creates the actual ticket tiers that customers buy from.
    """
    from app.models.ticket import TicketTier
    strategy = await get_or_404(db, strategy_id)
    for st in strategy.tiers:
        tier = TicketTier(
            event_id=event_id,
            name=st.name,
            description=st.description,
            price_cents=st.price_cents,
            quantity=st.quantity,
            display_order=st.display_order,
        )
        db.add(tier)
    await db.flush()
