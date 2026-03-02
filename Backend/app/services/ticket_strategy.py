"""
Ticket Strategy CRUD: reusable ticketing templates owned by organizers.
"""
from typing import Sequence
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ticket_strategy import TicketStrategy
from app.models.user import User
from app.core.exceptions import ForbiddenError
from app.repositories.ticket_strategy_repo import ticket_strategy_repo


async def list_strategies(db: AsyncSession, *, organizer_id: int) -> Sequence[TicketStrategy]:
    """List ticket strategies owned by this organizer."""
    return await ticket_strategy_repo.list_by_organizer(db, organizer_id)


async def get_by_id(db: AsyncSession, strategy_id: int) -> TicketStrategy | None:
    return await ticket_strategy_repo.get_with_tiers(db, strategy_id)


async def get_or_404(db: AsyncSession, strategy_id: int) -> TicketStrategy:
    return await ticket_strategy_repo.get_with_tiers_or_404(db, strategy_id)


async def create(
    db: AsyncSession,
    *,
    organizer_id: int,
    name: str,
    tiers: list[dict],
) -> TicketStrategy:
    """Create a ticket strategy with tiers."""
    strategy = TicketStrategy(organizer_id=organizer_id, name=name)
    return await ticket_strategy_repo.create_with_tiers(db, strategy, tiers)


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
        await ticket_strategy_repo.replace_tiers(db, strategy, tiers)
    else:
        await ticket_strategy_repo.flush(db)
    return await ticket_strategy_repo.get_with_tiers_or_404(db, strategy.id)


async def delete(db: AsyncSession, strategy: TicketStrategy, user: User) -> None:
    """Delete a ticket strategy (cascade deletes tiers)."""
    if strategy.organizer_id != user.id and user.role.value != "admin":
        raise ForbiddenError("You can only delete your own ticket strategies")
    await ticket_strategy_repo.delete_strategy(db, strategy)


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
    strategy = await ticket_strategy_repo.get_with_tiers_or_404(db, strategy_id)
    await ticket_strategy_repo.add_event_tiers(db, event_id, strategy.tiers)
