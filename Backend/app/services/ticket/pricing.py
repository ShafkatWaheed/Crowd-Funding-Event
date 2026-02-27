"""
Ticket price computation (discounts, pledge, milestone, early bird).
"""
from sqlalchemy import func, select

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import EventDiscount
from app.models.discount_strategy import EventDiscountStrategyLink
from app.models.funding import Funding, FundingStatus
from app.models.ticket import UserEventDiscount
from app.services import event as event_service

from app.services.ticket.tiers import get_tier_or_404

logger = get_logger("svc.ticket.pricing")


async def compute_ticket_price(
    db: AsyncSession,
    *,
    event_id: int,
    user_id: int,
    tier_id: int,
) -> dict:
    """
    Returns: tier_price_cents, common_discount_cents, selective_discount_cents,
    pledge_discount_cents, event_discount_cents, total_discount_cents, final_price_cents (>= 0).
    """
    event = await event_service.get_or_404(db, event_id)
    tier = await get_tier_or_404(db, event_id=event_id, tier_id=tier_id)
    base = tier.price_cents
    logger.debug("compute_ticket_price input", extra={"event_id": event_id, "user_id": user_id, "tier_id": tier_id, "base_cents": base})

    if base == 0:
        return {
            "tier_price_cents": 0,
            "common_discount_cents": 0,
            "selective_discount_cents": 0,
            "pledge_discount_cents": 0,
            "event_discount_cents": 0,
            "total_discount_cents": 0,
            "final_price_cents": 0,
        }

    common_cents = base * event.common_discount_percent // 100

    selective_cents = 0
    sel_q = select(UserEventDiscount).where(
        UserEventDiscount.event_id == event_id,
        UserEventDiscount.user_id == user_id,
    )
    sel_res = await db.execute(sel_q)
    ued = sel_res.scalar_one_or_none()
    if ued:
        if ued.discount_type == "percent":
            selective_cents = base * min(100, ued.value) // 100
        else:
            selective_cents = min(base, ued.value)

    sum_q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.user_id == user_id,
        Funding.status == FundingStatus.pledged,
    )
    total_pledged = int((await db.execute(sum_q)).scalar_one())
    has_pledged = total_pledged > 0

    pledge_cents = 0
    if event.pledge_discount_percent > 0 and has_pledged:
        raw_pledge_discount = total_pledged * event.pledge_discount_percent // 100
        from app.services import funding as funding_svc
        user_reserved = await funding_svc.get_user_reserved_spots(db, event_id, user_id)
        if user_reserved > 0:
            pledge_cents = raw_pledge_discount // user_reserved
        else:
            pledge_cents = raw_pledge_discount
        pledge_cents = min(pledge_cents, base)

    event_discount_cents = 0
    disc_q = select(EventDiscount).where(EventDiscount.event_id == event_id)
    disc_rows = list((await db.execute(disc_q)).scalars().all())

    from app.models.discount_strategy import CustomerDiscountClaim
    from sqlalchemy.orm import selectinload as _sload

    link_q = (
        select(EventDiscountStrategyLink)
        .options(_sload(EventDiscountStrategyLink.strategy))
        .where(EventDiscountStrategyLink.event_id == event_id)
    )
    links = list((await db.execute(link_q)).scalars().all())

    claim_q = select(CustomerDiscountClaim.link_id).where(
        CustomerDiscountClaim.user_id == user_id,
        CustomerDiscountClaim.link_id.in_([l.id for l in links]) if links else False,
    )
    claimed_link_ids = set((await db.execute(claim_q)).scalars().all()) if links else set()

    all_rules = [(d.discount_type, d.value, d.target) for d in disc_rows]
    for link in links:
        if link.auto_apply or link.id in claimed_link_ids:
            s = link.strategy
            all_rules.append((s.discount_type, s.value, s.target))

    for d_type, d_value, d_target in all_rules:
        if d_target == "pledgers" and not has_pledged:
            continue
        if d_target == "non_pledgers" and has_pledged:
            continue
        if d_type == "ticket_percent":
            event_discount_cents += base * min(100, d_value) // 100
        elif d_type == "pledge_percent":
            event_discount_cents += total_pledged * min(100, d_value) // 100

    milestone_cents = 0
    try:
        from app.models.milestone import FundingMilestoneSnapshot, FundingMilestoneUser
        snap_q = (
            select(FundingMilestoneSnapshot)
            .join(FundingMilestoneUser, FundingMilestoneUser.snapshot_id == FundingMilestoneSnapshot.id)
            .where(
                FundingMilestoneSnapshot.event_id == event_id,
                FundingMilestoneUser.user_id == user_id,
            )
            .order_by(FundingMilestoneSnapshot.milestone_percent.desc())
        )
        user_snapshots = list((await db.execute(snap_q)).scalars().unique().all())

        if user_snapshots:
            milestone_disc_q = select(EventDiscount).where(
                EventDiscount.event_id == event_id,
                EventDiscount.discount_type == "funding_milestone",
                EventDiscount.milestone_percent.isnot(None),
            )
            milestone_discs = list((await db.execute(milestone_disc_q)).scalars().all())
            user_milestone_pcts = {s.milestone_percent for s in user_snapshots}

            best_milestone_cents = 0
            for md in milestone_discs:
                if md.milestone_percent not in user_milestone_pcts:
                    continue
                disc_val = md.milestone_discount_value or md.value
                if md.discount_type == "funding_milestone":
                    mc = base * min(100, disc_val) // 100
                else:
                    mc = min(base, disc_val)
                best_milestone_cents = max(best_milestone_cents, mc)
            milestone_cents = best_milestone_cents
    except Exception:
        pass

    early_bird_cents = 0
    try:
        from app.models.milestone import EarlyBirdDiscount
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)

        eb_q = select(EarlyBirdDiscount).where(EarlyBirdDiscount.event_id == event_id)
        eb_discs = list((await db.execute(eb_q)).scalars().all())

        for eb in eb_discs:
            eb_amount = 0
            if eb.applies_to == "funding":
                eb_pledge_q = select(func.count()).where(
                    Funding.event_id == event_id,
                    Funding.user_id == user_id,
                    Funding.status == FundingStatus.pledged,
                    Funding.is_early_bird == True,  # noqa: E712
                )
                has_eb = int((await db.execute(eb_pledge_q)).scalar_one()) > 0
                if not has_eb:
                    continue
            elif eb.applies_to == "tickets":
                window_end = eb.window_end
                if now > window_end:
                    continue
            else:
                continue

            if eb.discount_type == "percent":
                eb_amount = base * min(100, eb.value) // 100
            elif eb.discount_type == "fixed_cents":
                eb_amount = min(base, eb.value)
            early_bird_cents = max(early_bird_cents, eb_amount)
    except Exception:
        pass

    standard_total = common_cents + selective_cents + pledge_cents + event_discount_cents
    raw_total = standard_total + milestone_cents + early_bird_cents

    cap_cents = base * getattr(event, "max_discount_percent", 100) // 100
    total_discount = min(raw_total, cap_cents, base)
    final = max(0, base - total_discount)
    logger.debug(
        "Price calculation result",
        extra={
            "event_id": event_id,
            "user_id": user_id,
            "tier_id": tier_id,
            "final_price_cents": final,
            "total_discount_cents": total_discount,
            "pledge_discount_cents": pledge_cents,
            "milestone_discount_cents": milestone_cents,
            "early_bird_discount_cents": early_bird_cents,
        },
    )
    return {
        "tier_price_cents": base,
        "common_discount_cents": common_cents,
        "selective_discount_cents": selective_cents,
        "pledge_discount_cents": pledge_cents,
        "event_discount_cents": event_discount_cents,
        "milestone_discount_cents": milestone_cents,
        "early_bird_discount_cents": early_bird_cents,
        "total_discount_cents": total_discount,
        "final_price_cents": final,
        "discount_capped": raw_total > cap_cents,
        "max_discount_percent": getattr(event, "max_discount_percent", 100),
    }
