"""
Funding summary and pledged totals (read-only queries).

All queries have been moved to FundingRepository.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.funding_repo import funding_repo


async def get_pledged_totals_for_events(
    db: AsyncSession,
    *,
    event_ids: list[int],
) -> dict[int, int]:
    """Return { event_id: total_pledged_cents } for each event. Used for list/cards."""
    return await funding_repo.get_pledged_totals_for_events(db, event_ids)


async def get_funding_aggregates_for_events(
    db: AsyncSession,
    *,
    event_ids: list[int],
) -> dict[int, tuple[int, int]]:
    """Return { event_id: (total_pledged_cents, total_reserved_spots) } in one query."""
    return await funding_repo.get_funding_aggregates_for_events(db, event_ids)


async def get_user_pledge_amounts_for_events(
    db: AsyncSession,
    *,
    user_id: int,
    event_ids: list[int],
) -> dict[int, int]:
    """Return { event_id: total_active_pledge_cents } for this user. Used for activity chips."""
    return await funding_repo.get_user_pledge_amounts_for_events(db, user_id, event_ids)


async def get_summary(db: AsyncSession, *, event_id: int) -> dict:
    """
    Returns funding summary including commission info and reserved spots.
    """
    from app.services import event as event_service
    event = await event_service.get_or_404(db, event_id)

    total = await funding_repo.get_total_pledged(db, event_id)
    platform_cut = await funding_repo.get_total_platform_cut(db, event_id)
    net = await funding_repo.get_total_net_to_organizer(db, event_id)
    backers = await funding_repo.get_backers_count(db, event_id)
    goal = event.funding_goal_cents
    goal_met = bool(goal is not None and total >= goal)

    total_reserved = await funding_repo.get_total_reserved_spots(db, event_id)

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
