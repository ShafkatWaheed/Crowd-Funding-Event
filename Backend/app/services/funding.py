"""
Funding / pledges: create pledge and compute funding summary.

MVP notes:
- This records pledges only (no payment gateway yet).
- A user can pledge multiple times to the same event (common crowdfunding behavior).
"""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.event import EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.user import User
from app.services import event as event_service


async def create_pledge(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    amount_cents: int,
) -> Funding:
    if amount_cents <= 0:
        raise ConflictError("amount_cents must be greater than 0")
    event = await event_service.get_or_404(db, event_id)
    if event.status == EventStatus.cancelled:
        raise ConflictError("Cannot pledge to a cancelled event")
    if event.status == EventStatus.ended:
        raise ConflictError("Cannot pledge to an ended event")

    pledge = Funding(
        event_id=event_id,
        user_id=user.id,
        amount_cents=amount_cents,
        status=FundingStatus.pledged,
    )
    db.add(pledge)
    await db.flush()
    await db.refresh(pledge)
    return pledge


async def get_summary(db: AsyncSession, *, event_id: int) -> dict:
    """
    Returns:
      - total_pledged_cents
      - backers_count (unique users)
      - goal_cents
      - goal_met (bool)
    """
    event = await event_service.get_or_404(db, event_id)
    total_q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    backers_q = select(func.count(func.distinct(Funding.user_id))).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    total = (await db.execute(total_q)).scalar_one()
    backers = (await db.execute(backers_q)).scalar_one()
    goal = event.funding_goal_cents
    goal_met = bool(goal is not None and total >= goal)
    return {
        "event_id": event_id,
        "total_pledged_cents": int(total),
        "backers_count": int(backers),
        "goal_cents": goal,
        "goal_met": goal_met,
    }
