"""
Fund escrow service: create, release stages, freeze, get status.
"""
from datetime import datetime, timezone

from sqlalchemy import select, func
from sqlalchemy.dialects.postgresql import insert as pg_insert
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
    total_q = select(func.coalesce(func.sum(Funding.net_to_organizer_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.status == FundingStatus.pledged,
    )
    total = int((await db.execute(total_q)).scalar_one())
    stmt = pg_insert(FundEscrow).values(
        event_id=event_id, total_held_cents=total,
    ).on_conflict_do_nothing(index_elements=["event_id"])
    await db.execute(stmt)
    await db.flush()
    escrow = (await db.execute(q)).scalar_one()
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


def _reject_if_blocked(escrow: FundEscrow) -> None:
    """Raise if escrow is frozen or waived."""
    if escrow.status == EscrowStatus.frozen:
        raise ConflictError("Escrow is frozen by admin")
    if escrow.status == EscrowStatus.waived:
        raise ConflictError("Escrow is waived for this community event")


async def _mark_waived(db: AsyncSession, event_id: int) -> FundEscrow:
    """Create/update escrow to waived status with audit log."""
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.status == EscrowStatus.waived:
        return escrow
    escrow.status = EscrowStatus.waived
    log = EscrowRelease(
        escrow_id=escrow.id, stage=0, amount_cents=0,
        released_by="system", reason="Community escrow disabled -- waived",
    )
    db.add(log)
    await db.flush()
    await db.refresh(escrow)
    return escrow


async def _ticket_sold_percent(db: AsyncSession, event_id: int, max_capacity: int) -> int:
    """Return percentage of max_capacity that has been sold (0-100)."""
    if max_capacity <= 0:
        return 0
    sold = (await db.execute(
        select(func.count()).select_from(TicketSale).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
        )
    )).scalar_one()
    return (sold * 100) // max_capacity


async def release_stage1(db: AsyncSession, *, event_id: int, released_by: str = "system") -> FundEscrow:
    """
    Release Stage 1: 30% of total held (40% for trusted organizers with score > 0.8).
    """
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage1_released_at:
        raise ConflictError("Stage 1 already released")
    _reject_if_blocked(escrow)

    pct = await settings_svc.get_int(db, "escrow_stage1_percent")

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
    """Release Stage 2: 40% of total held."""
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage2_released_at:
        raise ConflictError("Stage 2 already released")
    if not escrow.stage1_released_at:
        raise ConflictError("Stage 1 must be released first")
    _reject_if_blocked(escrow)

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
    """Release Stage 3: remaining (30%) of total held."""
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage3_released_at:
        raise ConflictError("Stage 3 already released")
    if not escrow.stage2_released_at:
        raise ConflictError("Stage 2 must be released first")
    _reject_if_blocked(escrow)

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
    if escrow.status not in (EscrowStatus.frozen, EscrowStatus.waived):
        raise ConflictError("Escrow is not frozen or waived")
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


# ---------------------------------------------------------------------------
# Auto-trigger functions (called by auto_transition_status / event lifecycle)
# ---------------------------------------------------------------------------

async def _check_community_waiver(db: AsyncSession, event: Event) -> FundEscrow | None:
    """If community escrow is disabled for this event, create a waived record and return it."""
    if getattr(event, "community_rules", False) and await settings_svc.get_bool(db, "community_escrow_disabled"):
        return await _mark_waived(db, event.id)
    return None


async def check_and_release_stage1(db: AsyncSession, *, event_id: int) -> FundEscrow | None:
    """
    Auto-check Stage 1 based on configured trigger mode.
    Modes:
      - ticket_percent: X% of max_capacity tickets sold
      - funding_end: funding stage ended (event left 'approved' with funding)
      - selling_started: event entered selling_tickets status
    """
    if not await settings_svc.get_bool(db, "escrow_stage1_trigger_enabled"):
        return None

    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        return None

    waived = await _check_community_waiver(db, event)
    if waived:
        return waived

    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage1_released_at:
        return None
    if escrow.status in (EscrowStatus.frozen, EscrowStatus.waived):
        return None

    mode = await settings_svc.get_str(db, "escrow_stage1_trigger_mode")

    if mode == "funding_end":
        if event.funding_end_at is None:
            return None
        funding_end = event.funding_end_at if event.funding_end_at.tzinfo else event.funding_end_at.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) < funding_end:
            return None
    elif mode == "selling_started":
        if event.status != EventStatus.selling_tickets:
            return None
    else:
        threshold = await settings_svc.get_int(db, "escrow_stage1_ticket_percent")
        if threshold <= 0:
            threshold = 50
        pct = await _ticket_sold_percent(db, event_id, event.max_capacity)
        if pct < threshold:
            return None

    return await release_stage1(db, event_id=event_id, released_by="system")


async def check_and_release_stage2(db: AsyncSession, *, event_id: int) -> FundEscrow | None:
    """
    Auto-check Stage 2 based on configured trigger mode.
    Modes:
      - ticket_percent: X% of max_capacity tickets sold
      - days_percent: X% of days elapsed from ticket_selling_started_at to start_time
    """
    if not await settings_svc.get_bool(db, "escrow_stage2_trigger_enabled"):
        return None

    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        return None

    waived = await _check_community_waiver(db, event)
    if waived:
        return waived

    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage2_released_at or not escrow.stage1_released_at:
        return None
    if escrow.status in (EscrowStatus.frozen, EscrowStatus.waived):
        return None

    mode = await settings_svc.get_str(db, "escrow_stage2_trigger_mode")

    if mode == "ticket_percent":
        threshold = await settings_svc.get_int(db, "escrow_stage2_ticket_percent")
        if threshold <= 0:
            threshold = 75
        pct = await _ticket_sold_percent(db, event_id, event.max_capacity)
        if pct < threshold:
            return None
    else:
        selling_start = getattr(event, "ticket_selling_started_at", None)
        if selling_start is None or event.start_time is None:
            return None
        selling_start_tz = selling_start if selling_start.tzinfo else selling_start.replace(tzinfo=timezone.utc)
        start_tz = event.start_time if event.start_time.tzinfo else event.start_time.replace(tzinfo=timezone.utc)
        total_window = (start_tz - selling_start_tz).total_seconds()
        if total_window <= 0:
            return None
        elapsed = (datetime.now(timezone.utc) - selling_start_tz).total_seconds()
        percent_elapsed = (elapsed / total_window) * 100
        threshold = await settings_svc.get_int(db, "escrow_stage2_days_percent")
        if threshold <= 0:
            threshold = 50
        if percent_elapsed < threshold:
            return None

    return await release_stage2(db, event_id=event_id, released_by="system")


async def check_and_release_stage3(db: AsyncSession, *, event_id: int) -> FundEscrow | None:
    """
    Auto-check Stage 3 based on configured trigger mode.
    Modes:
      - days_after: X days after event end_time
      - scan_threshold: event completed + X% of tickets scanned at door
    """
    if not await settings_svc.get_bool(db, "escrow_stage3_trigger_enabled"):
        return None

    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        return None

    waived = await _check_community_waiver(db, event)
    if waived:
        return waived

    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage3_released_at or not escrow.stage2_released_at:
        return None
    if escrow.status in (EscrowStatus.frozen, EscrowStatus.waived):
        return None

    mode = await settings_svc.get_str(db, "escrow_stage3_trigger_mode")

    if mode == "scan_threshold":
        if event.status != EventStatus.completed:
            return None
        threshold_pct = await settings_svc.get_int(db, "scan_threshold_percent")
        if threshold_pct <= 0:
            threshold_pct = 50
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
                return None
    else:
        if event.end_time is None:
            return None
        end_tz = event.end_time if event.end_time.tzinfo else event.end_time.replace(tzinfo=timezone.utc)
        days_after_cfg = await settings_svc.get_int(db, "escrow_stage3_days_after_event")
        if days_after_cfg <= 0:
            days_after_cfg = 7
        days_since_end = (datetime.now(timezone.utc) - end_tz).total_seconds() / 86400
        if days_since_end < days_after_cfg:
            return None

    return await release_stage3(db, event_id=event_id, released_by="system")


async def list_all_escrows(
    db: AsyncSession,
    *,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
) -> tuple[list[dict], int]:
    """List all escrows for admin dashboard. Returns (items, total)."""
    base = select(FundEscrow)
    if search:
        eid = None
        try:
            eid = int(search)
        except ValueError:
            pass
        if eid is not None:
            base = base.where(FundEscrow.event_id == eid)
        else:
            base = base.where(FundEscrow.event_id == -1)
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one()
    q = base.order_by(FundEscrow.updated_at.desc()).offset(offset).limit(limit)
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
    return result, int(total)
