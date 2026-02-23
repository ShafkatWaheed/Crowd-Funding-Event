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
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
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


# ─── Tier-linked reservation helpers ──────────────────────────────────

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
        # Also decrement the parent pledge's total reserved_spots
        pledge = await db.get(Funding, row.funding_id)
        if pledge:
            pledge.reserved_spots = max(0, pledge.reserved_spots - take)
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

    tier_availability: list[dict] = []
    if event.link_funding_to_tiers:
        tiers_q = select(TicketTier).where(TicketTier.event_id == event_id).order_by(TicketTier.display_order)
        tiers = list((await db.execute(tiers_q)).scalars().all())
        for t in tiers:
            if t.max_reserved_spots <= 0:
                continue
            reserved = await get_reserved_spots_for_tier(db, event_id, t.id)
            tier_availability.append({
                "tier_id": t.id,
                "tier_name": t.name,
                "price_cents": t.price_cents,
                "max_reserved_spots": t.max_reserved_spots,
                "reserved_so_far": reserved,
                "available": max(0, t.max_reserved_spots - reserved),
            })

    return {
        "amount_cents": amount_cents,
        "reserved_spots": reserved_spots,
        "cost_per_spot_cents": event.min_pledge_cents,
        "platform_cut_cents": platform_cut,
        "net_to_organizer_cents": net_to_organizer,
        "funding_commission_percent": funding_pct,
        "available_spots_for_user": available_for_user,
        "event_total_reserved_spots": event_total,
        "link_funding_to_tiers": event.link_funding_to_tiers,
        "tier_availability": tier_availability,
    }


# ─── Create pledge ──────────────────────────────────────────────────


async def create_pledge(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    amount_cents: int,
    reserved_spots: int = 0,
    tier_reservations: list[dict] | None = None,
) -> Funding:
    """Create a pledge with optional spot reservations.

    tier_reservations: list of {"tier_id": int, "spots": int} when
    event.link_funding_to_tiers is True.  In tier-linked mode the global
    reserved_spots field is auto-computed as the sum of per-tier spots.
    """
    if amount_cents <= 0:
        raise ConflictError("amount_cents must be greater than 0")
    if reserved_spots < 0:
        raise ConflictError("reserved_spots cannot be negative")

    event = await event_service.get_or_404(db, event_id)
    if event.status == EventStatus.cancelled:
        raise ConflictError("Cannot pledge to a cancelled event")
    if event.status == EventStatus.completed:
        raise ConflictError("Cannot pledge to an ended event")

    # Serialize capacity-sensitive operations per-event (auto-releases on commit/rollback)
    from sqlalchemy import text
    await db.execute(text("SELECT pg_advisory_xact_lock(:eid)"), {"eid": event_id})

    reg_q = select(Registration).where(
        Registration.event_id == event_id,
        Registration.user_id == user.id,
        Registration.status == RegistrationStatus.registered,
    )
    reg_result = await db.execute(reg_q)
    is_registered = reg_result.scalar_one_or_none() is not None
    is_guest = not is_registered

    # ── Tier-linked reservation mode ──
    if event.link_funding_to_tiers and tier_reservations:
        if is_guest:
            raise ConflictError("Only registered users can reserve spots. Please register first.")

        total_tier_spots = 0
        min_required_cents = 0

        for tr in tier_reservations:
            tid, spots = tr["tier_id"], tr["spots"]
            if spots <= 0:
                raise ConflictError(f"Spots must be >= 1 for tier {tid}")

            tier = (await db.execute(
                select(TicketTier).where(TicketTier.id == tid, TicketTier.event_id == event_id)
            )).scalar_one_or_none()
            if tier is None:
                raise ConflictError(f"Ticket tier {tid} not found for this event")
            if tier.max_reserved_spots <= 0:
                raise ConflictError(f"Tier '{tier.name}' does not allow spot reservations")

            already_reserved = await get_reserved_spots_for_tier(db, event_id, tid)
            if already_reserved + spots > tier.max_reserved_spots:
                avail = max(0, tier.max_reserved_spots - already_reserved)
                raise ConflictError(
                    f"Tier '{tier.name}' only has {avail} reservable spot(s) left "
                    f"(limit {tier.max_reserved_spots}, already reserved {already_reserved})"
                )

            min_required_cents += spots * tier.price_cents
            total_tier_spots += spots

        reserved_spots = total_tier_spots

        if amount_cents < min_required_cents:
            raise ConflictError(
                f"Pledge amount must be at least {min_required_cents} cents "
                f"to cover the selected tier reservations"
            )

        # Global capacity check
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

    # ── Legacy global reservation mode ──
    elif reserved_spots > 0:
        if is_guest:
            raise ConflictError("Only registered users can reserve spots. Please register first.")

        if event.max_reserved_spots_per_user <= 0:
            raise ConflictError("Spot reservation is not enabled for this event")

        min_required = reserved_spots * event.min_pledge_cents
        if amount_cents < min_required:
            raise ConflictError(
                f"Pledge amount must be at least {min_required} cents "
                f"to reserve {reserved_spots} spot(s) ({event.min_pledge_cents} cents/spot)"
            )

        user_existing_spots = await get_user_reserved_spots(db, event_id, user.id)
        if user_existing_spots + reserved_spots > event.max_reserved_spots_per_user:
            raise ConflictError(
                f"Cannot reserve {reserved_spots} more spot(s). "
                f"You already have {user_existing_spots} and the limit is {event.max_reserved_spots_per_user}."
            )

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
    else:
        if amount_cents < event.min_pledge_cents:
            raise ConflictError(
                f"Pledge amount must be at least {event.min_pledge_cents} cents (event minimum)"
            )

    # Compute platform commission
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

    # Create per-tier reservation rows
    if event.link_funding_to_tiers and tier_reservations:
        from app.models.funding import PledgeSpotReservation
        for tr in tier_reservations:
            row = PledgeSpotReservation(
                funding_id=pledge.id,
                ticket_tier_id=tr["tier_id"],
                spots=tr["spots"],
            )
            db.add(row)
        await db.flush()

    now = datetime.now(timezone.utc)
    pledge.receipt_number = f"PLG-{now.strftime('%Y%m%d')}-{event_id}-{pledge.id}"
    await db.flush()
    await db.refresh(pledge)

    # Check early bird funding window
    try:
        from app.models.milestone import EarlyBirdDiscount
        eb_q = select(EarlyBirdDiscount).where(
            EarlyBirdDiscount.event_id == event_id,
            EarlyBirdDiscount.applies_to == "funding",
        )
        eb_disc = (await db.execute(eb_q)).scalar_one_or_none()
        if eb_disc:
            now = datetime.now(timezone.utc)
            window_start = eb_disc.window_start or event.created_at
            if window_start <= now <= eb_disc.window_end:
                pledge.is_early_bird = True
                await db.flush()
    except Exception:
        pass

    # Check and create milestone snapshots if a new milestone was crossed
    try:
        await _check_milestone_snapshots(db, event)
    except Exception:
        pass

    try:
        from app.services import escrow as escrow_svc
        await escrow_svc.check_and_release_stage1(db, event_id=event_id)
    except Exception:
        pass

    return pledge


async def unpledge(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
) -> dict:
    """
    Unpledge: mark all pledged fundings for this user+event as refund_processing,
    release reserved spots immediately, and enqueue ARQ jobs for completion.
    Guest pledges are non-refundable.
    """
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
        f.status = FundingStatus.refund_processing

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

    # No payment gateway yet -- complete refunds immediately.
    # When a gateway is added, replace this with ARQ enqueue.
    for f in refundable:
        f.status = FundingStatus.refunded
    await db.flush()

    return {
        "refunded_cents": refunded_cents,
        "pledges_refunded": len(refundable),
        "guest_non_refundable_cents": int(guest_total),
        "status": "refund_processing" if refundable else "completed",
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
    When an event is cancelled, mark all pledged fundings as refund_processing
    and enqueue a bulk ARQ job. Returns count of pledges queued.
    """
    from sqlalchemy import update
    conditions = [
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    ]
    if not guest_refund:
        conditions.append(Funding.is_guest == False)  # noqa: E712
    # Transition through refund_processing then immediately to refunded.
    # When a payment gateway is added, stop at refund_processing and enqueue ARQ.
    await db.execute(
        update(Funding).where(*conditions).values(status=FundingStatus.refund_processing)
    )
    result = await db.execute(
        update(Funding)
        .where(Funding.event_id == event_id, Funding.status == FundingStatus.refund_processing)
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
    Mark all pledged fundings for this user+event as refund_processing
    and enqueue individual ARQ jobs. Returns count queued.
    """
    from sqlalchemy import update
    # Transition through refund_processing then immediately to refunded.
    await db.execute(
        update(Funding)
        .where(Funding.event_id == event_id, Funding.user_id == user_id, Funding.status == FundingStatus.pledged)
        .values(status=FundingStatus.refund_processing)
    )
    result = await db.execute(
        update(Funding)
        .where(Funding.event_id == event_id, Funding.user_id == user_id, Funding.status == FundingStatus.refund_processing)
        .values(status=FundingStatus.refunded)
    )
    return result.rowcount or 0


async def _check_milestone_snapshots(db: AsyncSession, event) -> None:
    """Create snapshots for any milestones newly crossed by the current funding level."""
    if not event.funding_goal_cents or event.funding_goal_cents <= 0:
        return

    from app.models.milestone import FundingMilestone, FundingMilestoneSnapshot, FundingMilestoneUser
    from app.models.event import EventDiscount

    total_q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
        Funding.event_id == event.id,
        Funding.status == FundingStatus.pledged,
    )
    total_pledged = int((await db.execute(total_q)).scalar_one())
    current_pct = total_pledged / event.funding_goal_cents * 100

    # Milestone discount thresholds from EventDiscount entries
    disc_q = select(EventDiscount).where(
        EventDiscount.event_id == event.id,
        EventDiscount.discount_type == "funding_milestone",
        EventDiscount.milestone_percent.isnot(None),
    )
    milestone_discounts = list((await db.execute(disc_q)).scalars().all())

    # Also check FundingMilestone entries (display milestones)
    fm_q = select(FundingMilestone).where(FundingMilestone.event_id == event.id)
    display_milestones = list((await db.execute(fm_q)).scalars().all())

    # Collect all milestone percentages that should trigger snapshots
    all_percents: set[int] = set()
    for d in milestone_discounts:
        if d.milestone_percent is not None:
            all_percents.add(d.milestone_percent)
    for m in display_milestones:
        all_percents.add(m.unlock_percent)

    if not all_percents:
        return

    # Get existing snapshots to avoid duplicates
    existing_q = select(FundingMilestoneSnapshot.milestone_percent).where(
        FundingMilestoneSnapshot.event_id == event.id,
    )
    existing_percents = set((await db.execute(existing_q)).scalars().all())

    # Current pledgers
    pledgers_q = select(func.distinct(Funding.user_id)).where(
        Funding.event_id == event.id,
        Funding.status == FundingStatus.pledged,
    )
    pledger_ids = list((await db.execute(pledgers_q)).scalars().all())

    for pct in sorted(all_percents):
        if pct in existing_percents:
            continue
        if current_pct < pct:
            continue
        snapshot = FundingMilestoneSnapshot(
            event_id=event.id,
            milestone_percent=pct,
        )
        db.add(snapshot)
        await db.flush()
        await db.refresh(snapshot)
        for uid in pledger_ids:
            db.add(FundingMilestoneUser(snapshot_id=snapshot.id, user_id=uid))
        await db.flush()


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


async def list_organizer_pledges(
    db: AsyncSession,
    *,
    organizer_id: int,
    status_filter: str | None = None,
    offset: int = 0,
    limit: int = 20,
) -> Sequence[Funding]:
    """List all pledges made to events owned by organizer_id."""
    from app.models.event import Event
    conditions = [Event.organizer_id == organizer_id]
    if status_filter and status_filter != "all":
        if status_filter == "donation":
            conditions.append(Funding.is_guest == True)  # noqa: E712
        else:
            conditions.append(Funding.status == status_filter)
            conditions.append(Funding.is_guest == False)  # noqa: E712
    q = (
        select(Funding)
        .join(Event, Funding.event_id == Event.id)
        .where(*conditions)
        .options(
            selectinload(Funding.event),
            selectinload(Funding.user),
        )
        .order_by(Funding.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(q)
    return list(result.scalars().unique().all())
