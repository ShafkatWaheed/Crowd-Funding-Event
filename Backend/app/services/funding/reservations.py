"""
Spot reservation and tier-linked reservation helpers.
"""
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.funding import Funding, FundingStatus


async def get_user_reserved_spots(db: AsyncSession, event_id: int, user_id: int) -> int:
    """Sum of remaining (unredeemed) reserved spots for this user on this event."""
    q = select(func.coalesce(func.sum(Funding.reserved_spots), 0)).where(
        Funding.event_id == event_id,
        Funding.user_id == user_id,
        Funding.status == FundingStatus.pledged,
    )
    return int((await db.execute(q)).scalar_one())


async def get_total_reserved_spots(db: AsyncSession, event_id: int) -> int:
    """Sum of all unredeemed reserved spots across all pledgers for this event."""
    q = select(func.coalesce(func.sum(Funding.reserved_spots), 0)).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    return int((await db.execute(q)).scalar_one())


async def get_total_reserved_spots_for_events(
    db: AsyncSession,
    *,
    event_ids: list[int],
) -> dict[int, int]:
    """Return { event_id: total_reserved_spots } for each event. Used for list/cards."""
    if not event_ids:
        return {}
    q = (
        select(Funding.event_id, func.coalesce(func.sum(Funding.reserved_spots), 0).label("total"))
        .where(
            Funding.event_id.in_(event_ids),
            Funding.status == FundingStatus.pledged,
        )
        .group_by(Funding.event_id)
    )
    result = await db.execute(q)
    return {int(row.event_id): int(row.total) for row in result.all()}


async def consume_one_reserved_spot(db: AsyncSession, event_id: int, user_id: int) -> None:
    """Decrement the oldest pledge's reserved_spots by 1 for this user+event."""
    q = (
        select(Funding)
        .where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
            Funding.reserved_spots > 0,
        )
        .order_by(Funding.created_at.asc())
        .limit(1)
        .with_for_update()
    )
    pledge = (await db.execute(q)).scalar_one_or_none()
    if pledge is None:
        raise ConflictError("No reserved spots available to consume")
    pledge.reserved_spots -= 1
    await db.flush()


async def get_reserved_spots_for_tiers(
    db: AsyncSession, event_id: int, tier_ids: list[int]
) -> dict[int, int]:
    """Total reserved spots per tier across all pledgers. Returns {tier_id: spots}."""
    from app.models.funding import PledgeSpotReservation
    if not tier_ids:
        return {}
    q = (
        select(
            PledgeSpotReservation.ticket_tier_id,
            func.coalesce(func.sum(PledgeSpotReservation.spots), 0).label("total"),
        )
        .join(Funding, PledgeSpotReservation.funding_id == Funding.id)
        .where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
            PledgeSpotReservation.ticket_tier_id.in_(tier_ids),
        )
        .group_by(PledgeSpotReservation.ticket_tier_id)
    )
    return {int(r.ticket_tier_id): int(r.total) for r in (await db.execute(q)).all()}


async def get_reserved_spots_for_tier(db: AsyncSession, event_id: int, tier_id: int) -> int:
    """Total reserved spots for a specific tier across all pledgers."""
    from app.models.funding import PledgeSpotReservation
    q = (
        select(func.coalesce(func.sum(PledgeSpotReservation.spots), 0))
        .join(Funding, PledgeSpotReservation.funding_id == Funding.id)
        .where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
            PledgeSpotReservation.ticket_tier_id == tier_id,
        )
    )
    return int((await db.execute(q)).scalar_one())


async def get_user_reserved_spots_for_tier(
    db: AsyncSession, event_id: int, user_id: int, tier_id: int
) -> int:
    """User's reserved spots for a specific tier."""
    from app.models.funding import PledgeSpotReservation
    q = (
        select(func.coalesce(func.sum(PledgeSpotReservation.spots), 0))
        .join(Funding, PledgeSpotReservation.funding_id == Funding.id)
        .where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
            PledgeSpotReservation.ticket_tier_id == tier_id,
        )
    )
    return int((await db.execute(q)).scalar_one())


async def consume_reserved_spots_for_tier(
    db: AsyncSession, event_id: int, user_id: int, tier_id: int, count: int
) -> None:
    """Decrement reservation rows for user+tier, consuming from oldest pledge first."""
    from app.models.funding import PledgeSpotReservation
    remaining = count
    q = (
        select(PledgeSpotReservation)
        .join(Funding, PledgeSpotReservation.funding_id == Funding.id)
        .where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
            PledgeSpotReservation.ticket_tier_id == tier_id,
            PledgeSpotReservation.spots > 0,
        )
        .order_by(Funding.created_at.asc())
        .with_for_update()
    )
    rows = list((await db.execute(q)).scalars().all())
    for row in rows:
        if remaining <= 0:
            break
        take = min(remaining, row.spots)
        row.spots -= take
        remaining -= take
        pledge = await db.get(Funding, row.funding_id)
        if pledge:
            pledge.reserved_spots = max(0, pledge.reserved_spots - take)
    await db.flush()
