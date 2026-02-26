"""
Create pledge, unpledge, refunds, and list pledges.
"""
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import ConflictError
from app.models.event import EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
from app.models.user import User

from app.services.funding.reservations import (
    get_reserved_spots_for_tier,
    get_reserved_spots_for_tiers,
    get_total_reserved_spots,
    get_user_reserved_spots,
)


async def pledge_preview(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    amount_cents: int,
    reserved_spots: int = 0,
) -> dict:
    """Compute an invoice preview before confirming a pledge."""
    from app.services import event as event_service
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
        reservable_ids = [t.id for t in tiers if t.max_reserved_spots > 0]
        reserved_map = await get_reserved_spots_for_tiers(db, event_id, reservable_ids)
        for t in tiers:
            if t.max_reserved_spots <= 0:
                continue
            reserved = reserved_map.get(t.id, 0)
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
    event.link_funding_to_tiers is True.
    """
    if amount_cents <= 0:
        raise ConflictError("amount_cents must be greater than 0")
    if reserved_spots < 0:
        raise ConflictError("reserved_spots cannot be negative")

    from app.services import event as event_service
    event = await event_service.get_or_404(db, event_id)
    if event.status == EventStatus.cancelled:
        raise ConflictError("Cannot pledge to a cancelled event")
    if event.status == EventStatus.completed:
        raise ConflictError("Cannot pledge to an ended event")

    from app.services.age_verification import enforce_age_limit
    enforce_age_limit(user.birthday, event.age_restricted, event.min_age, "back this event")

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

    if event.link_funding_to_tiers and tier_reservations:
        if is_guest:
            raise ConflictError("Only registered users can reserve spots. Please register first.")

        total_tier_spots = 0
        min_required_cents = 0

        tier_ids_needed = [tr["tier_id"] for tr in tier_reservations]
        tiers_map = {t.id: t for t in (await db.execute(
            select(TicketTier).where(
                TicketTier.id.in_(tier_ids_needed),
                TicketTier.event_id == event_id,
            )
        )).scalars().all()}
        reserved_map = await get_reserved_spots_for_tiers(db, event_id, tier_ids_needed)

        for tr in tier_reservations:
            tid, spots = tr["tier_id"], tr["spots"]
            if spots <= 0:
                raise ConflictError(f"Spots must be >= 1 for tier {tid}")

            tier = tiers_map.get(tid)
            if tier is None:
                raise ConflictError(f"Ticket tier {tid} not found for this event")
            if tier.max_reserved_spots <= 0:
                raise ConflictError(f"Tier '{tier.name}' does not allow spot reservations")

            already_reserved = reserved_map.get(tid, 0)
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

    from app.services import platform_settings as settings_svc
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")
    if getattr(event, "community_rules", False):
        override = await settings_svc.get_str(db, "community_funding_commission_percent")
        if override is not None and override != "":
            funding_pct = int(override)
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

    for f in refundable:
        f.status = FundingStatus.refunded
    await db.flush()

    return {
        "refunded_cents": refunded_cents,
        "pledges_refunded": len(refundable),
        "guest_non_refundable_cents": int(guest_total),
        "status": "refund_processing" if refundable else "completed",
    }


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

    disc_q = select(EventDiscount).where(
        EventDiscount.event_id == event.id,
        EventDiscount.discount_type == "funding_milestone",
        EventDiscount.milestone_percent.isnot(None),
    )
    milestone_discounts = list((await db.execute(disc_q)).scalars().all())

    fm_q = select(FundingMilestone).where(FundingMilestone.event_id == event.id)
    display_milestones = list((await db.execute(fm_q)).scalars().all())

    all_percents: set[int] = set()
    for d in milestone_discounts:
        if d.milestone_percent is not None:
            all_percents.add(d.milestone_percent)
    for m in display_milestones:
        all_percents.add(m.unlock_percent)

    if not all_percents:
        return

    existing_q = select(FundingMilestoneSnapshot.milestone_percent).where(
        FundingMilestoneSnapshot.event_id == event.id,
    )
    existing_percents = set((await db.execute(existing_q)).scalars().all())

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


async def refund_all_pledges_for_event(db: AsyncSession, *, event_id: int, guest_refund: bool = True) -> int:
    """When an event is cancelled, mark all pledged fundings as refunded. Returns count."""
    from sqlalchemy import update
    conditions = [
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    ]
    if not guest_refund:
        conditions.append(Funding.is_guest == False)  # noqa: E712
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
    """Mark all pledged fundings for this user+event as refunded. Returns count."""
    from sqlalchemy import update
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


async def list_pledges_by_user(
    db: AsyncSession,
    *,
    user_id: int,
    offset: int = 0,
    limit: int = 20,
) -> Sequence[Funding]:
    """List all pledges for a user."""
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
    event_status: str | None = None,
    genre: str | None = None,
    event_id: int | None = None,
    offset: int = 0,
    limit: int = 20,
) -> Sequence[Funding]:
    """List all pledges made to events owned by organizer_id."""
    from app.models.event import Event
    from app.models.event import EventStatus
    conditions = [Event.organizer_id == organizer_id]
    if event_status:
        try:
            conditions.append(Event.status == EventStatus(event_status))
        except ValueError:
            pass
    if genre:
        conditions.append(Event.genre == genre)
    if event_id:
        conditions.append(Event.id == event_id)
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


async def list_all_pledges_for_admin(
    db: AsyncSession,
    *,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
    status: str | None = None,
    is_donation: bool | None = None,
) -> tuple[Sequence[Funding], int]:
    """List fundings across events for admin, optionally filtered by status/donation. Returns (items, total)."""
    from app.models.event import Event
    from sqlalchemy import or_ as sql_or
    base = (
        select(Funding)
        .join(Event, Funding.event_id == Event.id)
    )
    if status:
        try:
            base = base.where(Funding.status == FundingStatus(status))
        except ValueError:
            pass
    if is_donation is True:
        base = base.where(Funding.is_guest == True)  # noqa: E712
    elif is_donation is False:
        base = base.where(Funding.is_guest == False)  # noqa: E712
    if search:
        pattern = f"%{search}%"
        base = base.outerjoin(User, Funding.user_id == User.id).where(
            sql_or(Event.title.ilike(pattern), User.display_name.ilike(pattern))
        )
    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar_one()
    q = (
        base
        .options(
            selectinload(Funding.event),
            selectinload(Funding.user),
        )
        .order_by(Funding.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(q)
    return list(result.scalars().unique().all()), int(total)


async def refund_pledge_by_id(
    db: AsyncSession, *, event_id: int, funding_id: int,
) -> int:
    """Admin-only: mark a single pledge as refunded. Returns 1 if found and refunded."""
    from sqlalchemy import update
    result = await db.execute(
        update(Funding)
        .where(
            Funding.id == funding_id,
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        )
        .values(status=FundingStatus.refund_processing)
    )
    if result.rowcount:
        await db.execute(
            update(Funding)
            .where(
                Funding.id == funding_id,
                Funding.event_id == event_id,
                Funding.status == FundingStatus.refund_processing,
            )
            .values(status=FundingStatus.refunded)
        )
    return result.rowcount or 0
