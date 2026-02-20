"""
Funding / pledges: create pledge and compute funding summary.

MVP notes:
- This records pledges only (no payment gateway yet).
- A user can pledge multiple times to the same event (common crowdfunding behavior).
- Spot reservation: pledgers can reserve future ticket spots (counted toward capacity).
"""

from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import ConflictError, NotFoundError
from app.models.event import EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.user import User
from app.services import event as event_service


# ─── Spot reservation helpers ───────────────────────────────────────


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


# ─── Pledge preview (invoice) ───────────────────────────────────────


async def pledge_preview(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    amount_cents: int,
    reserved_spots: int = 0,
) -> dict:
    """Compute an invoice preview before confirming a pledge."""
    event = await event_service.get_or_404(db, event_id)

    from app.services import platform_settings as settings_svc
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")
    platform_cut = amount_cents * funding_pct // 100
    net_to_organizer = amount_cents - platform_cut

    user_existing = await get_user_reserved_spots(db, event_id, user.id)
    max_per_user = event.max_reserved_spots_per_user
    available_for_user = max(0, max_per_user - user_existing)

    event_total = await get_total_reserved_spots(db, event_id)

    return {
        "amount_cents": amount_cents,
        "reserved_spots": reserved_spots,
        "cost_per_spot_cents": event.min_pledge_cents,
        "platform_cut_cents": platform_cut,
        "net_to_organizer_cents": net_to_organizer,
        "funding_commission_percent": funding_pct,
        "available_spots_for_user": available_for_user,
        "event_total_reserved_spots": event_total,
    }


# ─── Create pledge ──────────────────────────────────────────────────


async def create_pledge(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    amount_cents: int,
    reserved_spots: int = 0,
) -> Funding:
    if amount_cents <= 0:
        raise ConflictError("amount_cents must be greater than 0")
    if reserved_spots < 0:
        raise ConflictError("reserved_spots cannot be negative")

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

    # ── Spot reservation validation ──
    if reserved_spots > 0:
        if is_guest:
            raise ConflictError("Only registered users can reserve spots. Please register first.")

        if event.max_reserved_spots_per_user <= 0:
            raise ConflictError("Spot reservation is not enabled for this event")

        # Amount must cover spots
        min_required = reserved_spots * event.min_pledge_cents
        if amount_cents < min_required:
            raise ConflictError(
                f"Pledge amount must be at least {min_required} cents "
                f"to reserve {reserved_spots} spot(s) ({event.min_pledge_cents} cents/spot)"
            )

        # Per-user limit
        user_existing_spots = await get_user_reserved_spots(db, event_id, user.id)
        if user_existing_spots + reserved_spots > event.max_reserved_spots_per_user:
            raise ConflictError(
                f"Cannot reserve {reserved_spots} more spot(s). "
                f"You already have {user_existing_spots} and the limit is {event.max_reserved_spots_per_user}."
            )

        # Event capacity check: tickets_sold + total_reserved + new <= max_capacity
        total_reserved = await get_total_reserved_spots(db, event_id)
        tickets_sold_q = select(func.count()).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
        )
        tickets_sold = int((await db.execute(tickets_sold_q)).scalar_one())
        occupied = tickets_sold + total_reserved
        if occupied + reserved_spots > event.max_capacity:
            available = max(0, event.max_capacity - occupied)
            raise ConflictError(
                f"Not enough capacity to reserve {reserved_spots} spot(s). "
                f"Only {available} spot(s) available."
            )

    # Compute platform commission on pledge
    from app.services import platform_settings as settings_svc
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")
    platform_cut = amount_cents * funding_pct // 100
    net_to_organizer = amount_cents - platform_cut

    pledge = Funding(
        event_id=event_id,
        user_id=user.id,
        amount_cents=amount_cents,
        platform_cut_cents=platform_cut,
        net_to_organizer_cents=net_to_organizer,
        status=FundingStatus.pledged,
        is_guest=is_guest,
        reserved_spots=reserved_spots,
    )
    db.add(pledge)
    await db.flush()
    await db.refresh(pledge)

    # Generate pledge receipt number: PLG-YYYYMMDD-eventId-pledgeId
    now = datetime.now(timezone.utc)
    pledge.receipt_number = f"PLG-{now.strftime('%Y%m%d')}-{event_id}-{pledge.id}"
    await db.flush()
    await db.refresh(pledge)

    # Auto-check escrow stage 1 release (goal met + date + venue)
    try:
        from app.services import escrow as escrow_svc
        await escrow_svc.check_and_release_stage1(db, event_id=event_id)
    except Exception:
        pass  # non-critical

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
    Returns funding summary including commission info and reserved spots.
    """
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
    offset: int = 0,
    limit: int = 20,
) -> Sequence[Funding]:
    """List all pledges for a user (so they can see which events they've pledged to)."""
    q = (
        select(Funding)
        .where(Funding.user_id == user_id)
        .options(selectinload(Funding.event))
        .order_by(Funding.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(q)
    return result.scalars().unique().all()
