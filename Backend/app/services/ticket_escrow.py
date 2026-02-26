"""
Ticket escrow service: create, release stages, freeze, auto-triggers.

Mirrors FundEscrow but tracks ticket sales revenue with post-event triggers:
  Stage 1: N days after event completed (grace period)
  Stage 2: N days + refund rate < threshold
  Stage 3: N days + no open disputes
"""
from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.escrow import EscrowStatus, TicketEscrow
from app.models.event import Event, EventStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.user import User
from app.services import platform_settings as settings_svc


async def get_or_create(db: AsyncSession, *, event_id: int) -> TicketEscrow:
    q = select(TicketEscrow).where(TicketEscrow.event_id == event_id)
    escrow = (await db.execute(q)).scalar_one_or_none()
    if escrow:
        return escrow
    total = await _calc_total(db, event_id)
    stmt = pg_insert(TicketEscrow).values(
        event_id=event_id, total_held_cents=total,
    ).on_conflict_do_nothing(index_elements=["event_id"])
    await db.execute(stmt)
    await db.flush()
    return (await db.execute(q)).scalar_one()


async def _calc_total(db: AsyncSession, event_id: int) -> int:
    """Sum of net ticket revenue (amount_paid - commission) for purchased tickets."""
    result = (await db.execute(
        select(func.coalesce(
            func.sum(TicketSale.amount_paid_cents - TicketSale.commission_cents), 0
        )).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
        )
    )).scalar_one()
    return int(result)


async def refresh_total(db: AsyncSession, event_id: int) -> TicketEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    escrow.total_held_cents = await _calc_total(db, event_id)
    await db.flush()
    return escrow


def _reject_if_blocked(escrow: TicketEscrow) -> None:
    if escrow.status == EscrowStatus.frozen:
        raise ConflictError("Ticket escrow is frozen")
    if escrow.status == EscrowStatus.refunded:
        raise ConflictError("Ticket escrow has been refunded")


async def release_stage1(db: AsyncSession, *, event_id: int, released_by: str = "system") -> TicketEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage1_released_at:
        raise ConflictError("Ticket escrow Stage 1 already released")
    _reject_if_blocked(escrow)

    pct = await settings_svc.get_int(db, "ticket_escrow_stage1_percent")
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage1_released_cents = amount
    escrow.stage1_released_at = now
    escrow.status = EscrowStatus.partially_released
    await db.flush()
    return escrow


async def release_stage2(db: AsyncSession, *, event_id: int, released_by: str = "system") -> TicketEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage2_released_at:
        raise ConflictError("Ticket escrow Stage 2 already released")
    if not escrow.stage1_released_at:
        raise ConflictError("Ticket escrow Stage 1 must be released first")
    _reject_if_blocked(escrow)

    pct = await settings_svc.get_int(db, "ticket_escrow_stage2_percent")
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage2_released_cents = amount
    escrow.stage2_released_at = now
    await db.flush()
    return escrow


async def release_stage3(db: AsyncSession, *, event_id: int, released_by: str = "system") -> TicketEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage3_released_at:
        raise ConflictError("Ticket escrow Stage 3 already released")
    if not escrow.stage2_released_at:
        raise ConflictError("Ticket escrow Stage 2 must be released first")
    _reject_if_blocked(escrow)

    pct = await settings_svc.get_int(db, "ticket_escrow_stage3_percent")
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage3_released_cents = amount
    escrow.stage3_released_at = now
    escrow.status = EscrowStatus.fully_released
    await db.flush()
    return escrow


async def freeze(db: AsyncSession, *, event_id: int) -> TicketEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    escrow.status = EscrowStatus.frozen
    await db.flush()
    return escrow


async def unfreeze(db: AsyncSession, *, event_id: int) -> TicketEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.status != EscrowStatus.frozen:
        raise ConflictError("Ticket escrow is not frozen")
    if escrow.stage3_released_at:
        escrow.status = EscrowStatus.fully_released
    elif escrow.stage1_released_at:
        escrow.status = EscrowStatus.partially_released
    else:
        escrow.status = EscrowStatus.holding
    await db.flush()
    return escrow


async def list_all(
    db: AsyncSession, *, offset: int = 0, limit: int = 20, search: str | None = None,
) -> tuple[list[dict], int]:
    base = (
        select(TicketEscrow, Event.title.label("event_title"),
               User.display_name.label("organizer_name"), User.email.label("organizer_email"))
        .join(Event, TicketEscrow.event_id == Event.id)
        .join(User, Event.organizer_id == User.id)
    )
    if search:
        filters = [Event.title.ilike(f"%{search}%")]
        try:
            filters.append(TicketEscrow.event_id == int(search))
        except ValueError:
            pass
        base = base.where(or_(*filters))

    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one()
    rows = (await db.execute(base.order_by(TicketEscrow.updated_at.desc()).offset(offset).limit(limit))).all()
    result = []
    for row in rows:
        e = row[0]
        released = e.stage1_released_cents + e.stage2_released_cents + e.stage3_released_cents
        result.append({
            "id": e.id, "event_id": e.event_id, "event_title": row.event_title,
            "organizer_name": row.organizer_name, "organizer_email": row.organizer_email,
            "total_held_cents": e.total_held_cents, "total_released_cents": released,
            "remaining_cents": max(0, e.total_held_cents - released),
            "status": e.status.value,
            "stage1_released_at": e.stage1_released_at.isoformat() if e.stage1_released_at else None,
            "stage2_released_at": e.stage2_released_at.isoformat() if e.stage2_released_at else None,
            "stage3_released_at": e.stage3_released_at.isoformat() if e.stage3_released_at else None,
        })
    return result, int(total)


# ---------------------------------------------------------------------------
# Auto-trigger functions
# ---------------------------------------------------------------------------

async def check_and_release_stage1(db: AsyncSession, *, event_id: int) -> TicketEscrow | None:
    """Stage 1: event completed + N days grace period."""
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event or event.status != EventStatus.completed:
        return None
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage1_released_at or escrow.status in (EscrowStatus.frozen, EscrowStatus.refunded):
        return None

    days_required = await settings_svc.get_int(db, "ticket_escrow_stage1_days_after_event")
    if not event.end_time:
        return None
    end_tz = event.end_time if event.end_time.tzinfo else event.end_time.replace(tzinfo=timezone.utc)
    days_since = (datetime.now(timezone.utc) - end_tz).total_seconds() / 86400
    if days_since < days_required:
        return None

    return await release_stage1(db, event_id=event_id, released_by="system")


async def check_and_release_stage2(db: AsyncSession, *, event_id: int) -> TicketEscrow | None:
    """Stage 2: N days after event + refund rate below threshold."""
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event or event.status != EventStatus.completed:
        return None
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage2_released_at or not escrow.stage1_released_at:
        return None
    if escrow.status in (EscrowStatus.frozen, EscrowStatus.refunded):
        return None

    days_required = await settings_svc.get_int(db, "ticket_escrow_stage2_days_after_event")
    if not event.end_time:
        return None
    end_tz = event.end_time if event.end_time.tzinfo else event.end_time.replace(tzinfo=timezone.utc)
    days_since = (datetime.now(timezone.utc) - end_tz).total_seconds() / 86400
    if days_since < days_required:
        return None

    max_rate = await settings_svc.get_int(db, "ticket_escrow_stage2_max_refund_rate")
    total_sold = (await db.execute(
        select(func.count()).select_from(TicketSale).where(
            TicketSale.event_id == event_id,
            TicketSale.status.in_([TicketSaleStatus.purchased, TicketSaleStatus.refunded,
                                   TicketSaleStatus.refund_processing]),
        )
    )).scalar_one()
    total_refunds = (await db.execute(
        select(func.count()).select_from(TicketSale).where(
            TicketSale.event_id == event_id,
            TicketSale.status.in_([TicketSaleStatus.refunded, TicketSaleStatus.refund_processing]),
        )
    )).scalar_one()

    if total_sold > 0:
        refund_rate = (total_refunds * 100) // total_sold
        if refund_rate > max_rate:
            return None

    return await release_stage2(db, event_id=event_id, released_by="system")


async def check_and_release_stage3(db: AsyncSession, *, event_id: int) -> TicketEscrow | None:
    """Stage 3: N days after event + no open disputes."""
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event or event.status != EventStatus.completed:
        return None
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage3_released_at or not escrow.stage2_released_at:
        return None
    if escrow.status in (EscrowStatus.frozen, EscrowStatus.refunded):
        return None

    days_required = await settings_svc.get_int(db, "ticket_escrow_stage3_days_after_event")
    if not event.end_time:
        return None
    end_tz = event.end_time if event.end_time.tzinfo else event.end_time.replace(tzinfo=timezone.utc)
    days_since = (datetime.now(timezone.utc) - end_tz).total_seconds() / 86400
    if days_since < days_required:
        return None

    require_no_disputes = await settings_svc.get_bool(db, "ticket_escrow_stage3_require_no_disputes")
    if require_no_disputes:
        from app.models.dispute import Dispute, DisputeStatus
        open_disputes = (await db.execute(
            select(func.count()).select_from(Dispute).where(
                Dispute.event_id == event_id,
                Dispute.status.in_([DisputeStatus.open, DisputeStatus.evidence_submitted]),
            )
        )).scalar_one()
        if open_disputes > 0:
            return None

    return await release_stage3(db, event_id=event_id, released_by="system")
