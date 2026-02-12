"""
Funding / pledges: create pledge and compute funding summary.

MVP notes:
- This records pledges only (no payment gateway yet).
- A user can pledge multiple times to the same event (common crowdfunding behavior).
"""

from typing import Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import ConflictError, NotFoundError
from app.models.event import EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.registration import Registration, RegistrationStatus
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
    if amount_cents < event.min_pledge_cents:
        raise ConflictError(
            f"Pledge amount must be at least {event.min_pledge_cents} cents (event minimum)"
        )
    if event.status == EventStatus.cancelled:
        raise ConflictError("Cannot pledge to a cancelled event")
    if event.status == EventStatus.completed:
        raise ConflictError("Cannot pledge to an ended event")

    # Check if user is registered for this event
    reg_q = select(Registration).where(
        Registration.event_id == event_id,
        Registration.user_id == user.id,
        Registration.status == RegistrationStatus.registered,
    )
    reg_result = await db.execute(reg_q)
    is_registered = reg_result.scalar_one_or_none() is not None
    is_guest = not is_registered

    pledge = Funding(
        event_id=event_id,
        user_id=user.id,
        amount_cents=amount_cents,
        status=FundingStatus.pledged,
        is_guest=is_guest,
    )
    db.add(pledge)
    await db.flush()
    await db.refresh(pledge)
    return pledge


async def unpledge(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
) -> dict:
    """
    Unpledge: refund all pledged fundings for this user+event.
    Guest pledges are non-refundable.
    Returns dict with refunded_cents and guest_non_refundable_cents.
    """
    # Refund non-guest pledges
    from sqlalchemy import update
    q_refund = (
        select(Funding)
        .where(
            Funding.event_id == event_id,
            Funding.user_id == user.id,
            Funding.status == FundingStatus.pledged,
            Funding.is_guest == False,  # noqa: E712
        )
    )
    result = await db.execute(q_refund)
    refundable = list(result.scalars().all())
    refunded_cents = 0
    for f in refundable:
        refunded_cents += f.amount_cents
        f.status = FundingStatus.refunded

    # Count non-refundable guest pledges
    q_guest = (
        select(func.coalesce(func.sum(Funding.amount_cents), 0))
        .where(
            Funding.event_id == event_id,
            Funding.user_id == user.id,
            Funding.status == FundingStatus.pledged,
            Funding.is_guest == True,  # noqa: E712
        )
    )
    guest_total = (await db.execute(q_guest)).scalar_one()

    await db.flush()
    return {
        "refunded_cents": refunded_cents,
        "pledges_refunded": len(refundable),
        "guest_non_refundable_cents": int(guest_total),
    }


async def get_pledged_totals_for_events(
    db: AsyncSession,
    *,
    event_ids: list[int],
) -> dict[int, int]:
    """Return { event_id: total_pledged_cents } for each event. Used for list/cards."""
    if not event_ids:
        return {}
    from sqlalchemy import func
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


async def refund_all_pledges_for_event(db: AsyncSession, *, event_id: int, guest_refund: bool = True) -> int:
    """
    When an event is cancelled, mark all pledged fundings for that event as refunded.
    If guest_refund=False, only refund non-guest pledges (guest pledges left for admin decision).
    Returns count of pledges refunded.
    """
    from sqlalchemy import update
    conditions = [
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    ]
    if not guest_refund:
        conditions.append(Funding.is_guest == False)
    result = await db.execute(
        update(Funding)
        .where(*conditions)
        .values(status=FundingStatus.refunded)
    )
    return result.rowcount or 0


async def refund_pledges_for_user_event(
    db: AsyncSession,
    *,
    event_id: int,
    user_id: int,
) -> int:
    """
    Mark all pledged fundings for this user+event as refunded.
    Returns count of pledges refunded. Only affects status=pledged.
    """
    from sqlalchemy import update
    result = await db.execute(
        update(Funding)
        .where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
        )
        .values(status=FundingStatus.refunded)
    )
    return result.rowcount or 0


async def list_pledges_by_user(
    db: AsyncSession,
    *,
    user_id: int,
) -> Sequence[Funding]:
    """List all pledges for a user (so they can see which events they've pledged to)."""
    q = (
        select(Funding)
        .where(Funding.user_id == user_id)
        .options(selectinload(Funding.event))
        .order_by(Funding.created_at.desc())
    )
    result = await db.execute(q)
    return result.scalars().unique().all()
