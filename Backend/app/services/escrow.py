"""
Fund escrow service: create, release stages, freeze, get status.
"""
from datetime import datetime, timezone

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.models.escrow import EscrowRelease, EscrowStatus, FundEscrow
from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.services import platform_settings as settings_svc


async def get_or_create(db: AsyncSession, *, event_id: int) -> FundEscrow:
    """Get existing escrow or create one. total_held_cents = sum of pledged fundings net."""
    q = select(FundEscrow).where(FundEscrow.event_id == event_id)
    escrow = (await db.execute(q)).scalar_one_or_none()
    if escrow:
        return escrow
    # Compute total held from pledges (net after platform cut)
    total_q = select(func.coalesce(func.sum(Funding.net_to_organizer_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    total = int((await db.execute(total_q)).scalar_one())
    escrow = FundEscrow(event_id=event_id, total_held_cents=total)
    db.add(escrow)
    await db.flush()
    await db.refresh(escrow)
    return escrow


async def refresh_total(db: AsyncSession, escrow: FundEscrow) -> FundEscrow:
    """Recalculate total_held_cents from current pledges."""
    total_q = select(func.coalesce(func.sum(Funding.net_to_organizer_cents), 0)).where(
        Funding.event_id == escrow.event_id,
        Funding.status == FundingStatus.pledged,
    )
    total = int((await db.execute(total_q)).scalar_one())
    escrow.total_held_cents = total
    await db.flush()
    return escrow


async def release_stage1(db: AsyncSession, *, event_id: int, released_by: str = "system") -> FundEscrow:
    """
    Release Stage 1: 30% of total held (40% for trusted organizers with score > 0.8).
    Conditions: funding goal met + event date set + venue confirmed.
    """
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage1_released_at:
        raise ConflictError("Stage 1 already released")
    if escrow.status == EscrowStatus.frozen:
        raise ConflictError("Escrow is frozen by admin")

    pct = await settings_svc.get_int(db, "escrow_stage1_percent")

    # Trust score bump: organizers with score > 0.8 get 40% instead of default 30%
    from app.services import event as event_svc
    event = await event_svc.get_or_404(db, event_id)
    trust = await event_svc.get_organizer_trust_score(db, organizer_id=event.organizer_id)
    if trust["trust_score"] > 0.8 and pct < 40:
        pct = 40

    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage1_released_cents = amount
    escrow.stage1_released_at = now
    escrow.status = EscrowStatus.partially_released

    log = EscrowRelease(escrow_id=escrow.id, stage=1, amount_cents=amount, released_by=released_by, reason="Stage 1: planning confirmed")
    db.add(log)
    await db.flush()
    await db.refresh(escrow)
    return escrow


async def release_stage2(db: AsyncSession, *, event_id: int, released_by: str = "system") -> FundEscrow:
    """
    Release Stage 2: 40% of total held.
    Conditions: 48h before event start OR admin manual release.
    """
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage2_released_at:
        raise ConflictError("Stage 2 already released")
    if not escrow.stage1_released_at:
        raise ConflictError("Stage 1 must be released first")
    if escrow.status == EscrowStatus.frozen:
        raise ConflictError("Escrow is frozen by admin")

    pct = await settings_svc.get_int(db, "escrow_stage2_percent")
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage2_released_cents = amount
    escrow.stage2_released_at = now

    log = EscrowRelease(escrow_id=escrow.id, stage=2, amount_cents=amount, released_by=released_by, reason="Stage 2: event imminent")
    db.add(log)
    await db.flush()
    await db.refresh(escrow)
    return escrow


async def release_stage3(db: AsyncSession, *, event_id: int, released_by: str = "system") -> FundEscrow:
    """
    Release Stage 3: remaining (30%) of total held.
    Conditions: event completed + scan threshold met.
    """
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage3_released_at:
        raise ConflictError("Stage 3 already released")
    if not escrow.stage2_released_at:
        raise ConflictError("Stage 2 must be released first")
    if escrow.status == EscrowStatus.frozen:
        raise ConflictError("Escrow is frozen by admin")

    pct = await settings_svc.get_int(db, "escrow_stage3_percent")
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage3_released_cents = amount
    escrow.stage3_released_at = now
    escrow.status = EscrowStatus.fully_released

    log = EscrowRelease(escrow_id=escrow.id, stage=3, amount_cents=amount, released_by=released_by, reason="Stage 3: event completed")
    db.add(log)
    await db.flush()
    await db.refresh(escrow)
    return escrow


async def freeze(db: AsyncSession, *, event_id: int) -> FundEscrow:
    """Admin freezes payouts for an event."""
    escrow = await get_or_create(db, event_id=event_id)
    escrow.status = EscrowStatus.frozen
    await db.flush()
    await db.refresh(escrow)
    return escrow


async def unfreeze(db: AsyncSession, *, event_id: int) -> FundEscrow:
    """Admin unfreezes payouts."""
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.status != EscrowStatus.frozen:
        raise ConflictError("Escrow is not frozen")
    # Determine correct status
    if escrow.stage3_released_at:
        escrow.status = EscrowStatus.fully_released
    elif escrow.stage1_released_at or escrow.stage2_released_at:
        escrow.status = EscrowStatus.partially_released
    else:
        escrow.status = EscrowStatus.holding
    await db.flush()
    await db.refresh(escrow)
    return escrow


async def get_escrow_summary(db: AsyncSession, *, event_id: int) -> dict:
    """Return escrow info for display."""
    escrow = await get_or_create(db, event_id=event_id)
    total_released = escrow.stage1_released_cents + escrow.stage2_released_cents + escrow.stage3_released_cents
    return {
        "event_id": event_id,
        "total_held_cents": escrow.total_held_cents,
        "stage1_released_cents": escrow.stage1_released_cents,
        "stage1_released_at": escrow.stage1_released_at.isoformat() if escrow.stage1_released_at else None,
        "stage2_released_cents": escrow.stage2_released_cents,
        "stage2_released_at": escrow.stage2_released_at.isoformat() if escrow.stage2_released_at else None,
        "stage3_released_cents": escrow.stage3_released_cents,
        "stage3_released_at": escrow.stage3_released_at.isoformat() if escrow.stage3_released_at else None,
        "total_released_cents": total_released,
        "remaining_cents": max(0, escrow.total_held_cents - total_released),
        "status": escrow.status.value,
    }


async def check_and_release_stage1(db: AsyncSession, *, event_id: int) -> FundEscrow | None:
    """
    Auto-check: if funding goal met + event date confirmed + venue set, release stage 1.
    Called when pledge is created, event date is set, or event is updated.
    Returns the escrow if released, None if conditions not met or already released.
    """
    from app.services import event as event_svc
    event = await event_svc.get_or_404(db, event_id)

    # Check conditions
    if event.funding_goal_cents is None or event.funding_goal_cents <= 0:
        return None  # no funding goal, no escrow

    from app.services import funding as funding_svc
    summary = await funding_svc.get_summary(db, event_id=event_id)
    if not summary["goal_met"]:
        return None

    if event.start_time is None:
        return None  # date not set yet

    if event.venue_id is None:
        return None  # no venue

    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage1_released_at:
        return None  # already released

    return await release_stage1(db, event_id=event_id, released_by="system")


async def check_and_release_stage3(db: AsyncSession, *, event_id: int) -> FundEscrow | None:
    """
    Auto-check: if event completed + scan threshold met, release stage 3.
    Called when event status changes to completed.
    """
    from app.services import event as event_svc
    event = await event_svc.get_or_404(db, event_id)

    if event.status != EventStatus.completed:
        return None

    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage3_released_at or not escrow.stage2_released_at:
        return None

    # Check scan threshold
    threshold_pct = await settings_svc.get_int(db, "scan_threshold_percent")
    total_sold = (await db.execute(
        select(func.count()).select_from(TicketSale).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
        )
    )).scalar_one()
    total_scanned = (await db.execute(
        select(func.count()).select_from(TicketSale).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
            TicketSale.scanned_at.isnot(None),
        )
    )).scalar_one()

    if total_sold > 0:
        scan_pct = (total_scanned * 100) // total_sold
        if scan_pct < threshold_pct:
            return None  # below threshold, hold stage 3

    return await release_stage3(db, event_id=event_id, released_by="system")


async def list_all_escrows(db: AsyncSession) -> list[dict]:
    """List all escrows for admin dashboard."""
    q = select(FundEscrow).order_by(FundEscrow.updated_at.desc())
    rows = (await db.execute(q)).scalars().all()
    result = []
    for e in rows:
        total_released = e.stage1_released_cents + e.stage2_released_cents + e.stage3_released_cents
        result.append({
            "id": e.id,
            "event_id": e.event_id,
            "total_held_cents": e.total_held_cents,
            "total_released_cents": total_released,
            "remaining_cents": max(0, e.total_held_cents - total_released),
            "status": e.status.value,
            "stage1_released_at": e.stage1_released_at.isoformat() if e.stage1_released_at else None,
            "stage2_released_at": e.stage2_released_at.isoformat() if e.stage2_released_at else None,
            "stage3_released_at": e.stage3_released_at.isoformat() if e.stage3_released_at else None,
        })
    return result
