"""
Funding summary and pledged totals (read-only queries).
"""
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.funding import Funding, FundingStatus

from app.services.funding.reservations import get_total_reserved_spots


async def get_pledged_totals_for_events(
    db: AsyncSession,
    *,
    event_ids: list[int],
) -> dict[int, int]:
    """Return { event_id: total_pledged_cents } for each event. Used for list/cards."""
    if not event_ids:
        return {}
    q = (
        select(Funding.event_id, func.coalesce(func.sum(Funding.amount_cents), 0).label("total"))
        .where(
            Funding.event_id.in_(event_ids),
            Funding.status == FundingStatus.pledged,
        )
        .group_by(Funding.event_id)
    )
    result = await db.execute(q)
    return {int(row.event_id): int(row.total) for row in result.all()}


async def get_summary(db: AsyncSession, *, event_id: int) -> dict:
    """
    Returns funding summary including commission info and reserved spots.
    """
    from app.services import event as event_service
    event = await event_service.get_or_404(db, event_id)
    total_q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    platform_cut_q = select(func.coalesce(func.sum(Funding.platform_cut_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    net_q = select(func.coalesce(func.sum(Funding.net_to_organizer_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    backers_q = select(func.count(func.distinct(Funding.user_id))).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    total = (await db.execute(total_q)).scalar_one()
    platform_cut = (await db.execute(platform_cut_q)).scalar_one()
    net = (await db.execute(net_q)).scalar_one()
    backers = (await db.execute(backers_q)).scalar_one()
    goal = event.funding_goal_cents
    goal_met = bool(goal is not None and total >= goal)

    total_reserved = await get_total_reserved_spots(db, event_id)

    from app.services import platform_settings as settings_svc
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")

    return {
        "event_id": event_id,
        "total_pledged_cents": int(total),
        "total_platform_cut_cents": int(platform_cut),
        "total_net_to_organizer_cents": int(net),
        "backers_count": int(backers),
        "goal_cents": goal,
        "goal_met": goal_met,
        "funding_commission_percent": funding_pct,
        "total_reserved_spots": total_reserved,
    }
