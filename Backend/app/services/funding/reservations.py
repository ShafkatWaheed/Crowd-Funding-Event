"""
Spot reservation and tier-linked reservation helpers.

All queries have been moved to FundingRepository.
These thin wrappers maintain the existing public API so callers don't break.
"""
from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.funding_repo import funding_repo

logger = get_logger("svc.funding.reservations")


async def get_user_reserved_spots(db: AsyncSession, event_id: int, user_id: int) -> int:
    """Sum of remaining (unredeemed) reserved spots for this user on this event."""
    return await funding_repo.get_user_reserved_spots(db, event_id, user_id)


async def get_total_reserved_spots(db: AsyncSession, event_id: int) -> int:
    """Sum of all unredeemed reserved spots across all pledgers for this event."""
    return await funding_repo.get_total_reserved_spots(db, event_id)


async def get_total_reserved_spots_for_events(
    db: AsyncSession,
    *,
    event_ids: list[int],
) -> dict[int, int]:
    """Return { event_id: total_reserved_spots } for each event. Used for list/cards."""
    return await funding_repo.get_total_reserved_spots_for_events(db, event_ids)


async def consume_one_reserved_spot(db: AsyncSession, event_id: int, user_id: int) -> None:
    """Decrement the oldest pledge's reserved_spots by 1 for this user+event."""
    log_step(logger, "Consuming one reserved spot", event_id=event_id, user_id=user_id)
    await funding_repo.consume_one_reserved_spot(db, event_id, user_id)


async def get_reserved_spots_for_tiers(
    db: AsyncSession, event_id: int, tier_ids: list[int]
) -> dict[int, int]:
    """Total reserved spots per tier across all pledgers. Returns {tier_id: spots}."""
    return await funding_repo.get_reserved_spots_for_tiers(db, event_id, tier_ids)


async def get_reserved_spots_for_tier(db: AsyncSession, event_id: int, tier_id: int) -> int:
    """Total reserved spots for a specific tier across all pledgers."""
    return await funding_repo.get_reserved_spots_for_tier(db, event_id, tier_id)


async def get_user_reserved_spots_for_tier(
    db: AsyncSession, event_id: int, user_id: int, tier_id: int
) -> int:
    """User's reserved spots for a specific tier."""
    return await funding_repo.get_user_reserved_spots_for_tier(db, event_id, user_id, tier_id)


async def consume_reserved_spots_for_tier(
    db: AsyncSession, event_id: int, user_id: int, tier_id: int, count: int
) -> None:
    """Decrement reservation rows for user+tier, consuming from oldest pledge first."""
    log_step(logger, "Consuming reserved spots for tier", event_id=event_id, user_id=user_id, tier_id=tier_id, count=count)
    await funding_repo.consume_reserved_spots_for_tier(db, event_id, user_id, tier_id, count)
