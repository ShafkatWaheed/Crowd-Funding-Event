"""
Sponsor escrow service: create, release stages, freeze, auto-triggers.

Mirrors FundEscrow but tracks sponsor payment funds with sponsor-specific triggers:
  Stage 1: event_live or days_before_event
  Stage 2: event_started or ticket_percent
  Stage 3: days_after_event or sponsor_confirmed
"""
from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.escrow import EscrowStatus, SponsorEscrow
from app.models.event import Event, EventStatus
from app.models.sponsor import SponsorBid, SponsorPayment, SponsorshipCategory, PaymentStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.user import User
from app.services import platform_settings as settings_svc


async def get_or_create(db: AsyncSession, *, event_id: int) -> SponsorEscrow:
    q = select(SponsorEscrow).where(SponsorEscrow.event_id == event_id)
    escrow = (await db.execute(q)).scalar_one_or_none()
    if escrow:
        return escrow
    total = await _calc_total(db, event_id)
    stmt = pg_insert(SponsorEscrow).values(
        event_id=event_id, total_held_cents=total,
    ).on_conflict_do_nothing(index_elements=["event_id"])
    await db.execute(stmt)
    await db.flush()
    return (await db.execute(q)).scalar_one()


async def _calc_total(db: AsyncSession, event_id: int) -> int:
    """Sum of net sponsor payments for this event."""
    result = (await db.execute(
        select(func.coalesce(func.sum(SponsorPayment.net_to_organizer_cents), 0))
        .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorPayment.status == PaymentStatus.completed,
        )
    )).scalar_one()
    return int(result)


async def refresh_total(db: AsyncSession, event_id: int) -> SponsorEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    escrow.total_held_cents = await _calc_total(db, event_id)
    await db.flush()
    return escrow


def _reject_if_blocked(escrow: SponsorEscrow) -> None:
    if escrow.status == EscrowStatus.frozen:
        raise ConflictError("Sponsor escrow is frozen")
    if escrow.status == EscrowStatus.refunded:
        raise ConflictError("Sponsor escrow has been refunded")


async def release_stage1(db: AsyncSession, *, event_id: int, released_by: str = "system") -> SponsorEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage1_released_at:
        raise ConflictError("Sponsor escrow Stage 1 already released")
    _reject_if_blocked(escrow)

    pct = await settings_svc.get_int(db, "sponsor_escrow_stage1_percent")
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage1_released_cents = amount
    escrow.stage1_released_at = now
    escrow.status = EscrowStatus.partially_released
    await db.flush()
    return escrow


async def release_stage2(db: AsyncSession, *, event_id: int, released_by: str = "system") -> SponsorEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage2_released_at:
        raise ConflictError("Sponsor escrow Stage 2 already released")
    if not escrow.stage1_released_at:
        raise ConflictError("Sponsor escrow Stage 1 must be released first")
    _reject_if_blocked(escrow)

    pct = await settings_svc.get_int(db, "sponsor_escrow_stage2_percent")
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage2_released_cents = amount
    escrow.stage2_released_at = now
    await db.flush()
    return escrow


async def release_stage3(db: AsyncSession, *, event_id: int, released_by: str = "system") -> SponsorEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage3_released_at:
        raise ConflictError("Sponsor escrow Stage 3 already released")
    if not escrow.stage2_released_at:
        raise ConflictError("Sponsor escrow Stage 2 must be released first")
    _reject_if_blocked(escrow)

    pct = await settings_svc.get_int(db, "sponsor_escrow_stage3_percent")
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    escrow.stage3_released_cents = amount
    escrow.stage3_released_at = now
    escrow.status = EscrowStatus.fully_released
    await db.flush()
    return escrow


async def freeze(db: AsyncSession, *, event_id: int) -> SponsorEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    escrow.status = EscrowStatus.frozen
    await db.flush()
    return escrow


async def unfreeze(db: AsyncSession, *, event_id: int) -> SponsorEscrow:
    escrow = await get_or_create(db, event_id=event_id)
    if escrow.status != EscrowStatus.frozen:
        raise ConflictError("Sponsor escrow is not frozen")
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
        select(SponsorEscrow, Event.title.label("event_title"),
               User.display_name.label("organizer_name"), User.email.label("organizer_email"))
        .join(Event, SponsorEscrow.event_id == Event.id)
        .join(User, Event.organizer_id == User.id)
    )
    if search:
        filters = [Event.title.ilike(f"%{search}%")]
        try:
            filters.append(SponsorEscrow.event_id == int(search))
        except ValueError:
            pass
        base = base.where(or_(*filters))

    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one()
    rows = (await db.execute(base.order_by(SponsorEscrow.updated_at.desc()).offset(offset).limit(limit))).all()
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

async def _ticket_sold_percent(db: AsyncSession, event_id: int, max_capacity: int) -> int:
    if max_capacity <= 0:
        return 0
    sold = (await db.execute(
        select(func.count()).select_from(TicketSale).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
        )
    )).scalar_one()
    return (sold * 100) // max_capacity


async def check_and_release_stage1(db: AsyncSession, *, event_id: int) -> SponsorEscrow | None:
    """Stage 1: event goes live (or N days before event)."""
    if not await settings_svc.get_bool(db, "sponsor_escrow_stage1_trigger_enabled"):
        return None

    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        return None

    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage1_released_at or escrow.status in (EscrowStatus.frozen, EscrowStatus.refunded):
        return None

    mode = await settings_svc.get_str(db, "sponsor_escrow_stage1_trigger_mode")

    if mode == "event_live":
        if event.status != EventStatus.live:
            return None
    elif mode == "days_before_event":
        if not event.start_time:
            return None
        start_tz = event.start_time if event.start_time.tzinfo else event.start_time.replace(tzinfo=timezone.utc)
        days_before = await settings_svc.get_int(db, "sponsor_escrow_stage1_days_before_event")
        days_until = (start_tz - datetime.now(timezone.utc)).total_seconds() / 86400
        if days_until > days_before:
            return None
    else:
        return None

    result = await release_stage1(db, event_id=event_id, released_by="system")
    try:
        from app.worker.redis_pool import enqueue
        await enqueue("process_escrow_release", escrow_type="sponsor", escrow_id=result.id, stage=1)
    except Exception:
        pass
    return result


async def check_and_release_stage2(db: AsyncSession, *, event_id: int) -> SponsorEscrow | None:
    """Stage 2: event started (or ticket % threshold)."""
    if not await settings_svc.get_bool(db, "sponsor_escrow_stage2_trigger_enabled"):
        return None

    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        return None

    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage2_released_at or not escrow.stage1_released_at:
        return None
    if escrow.status in (EscrowStatus.frozen, EscrowStatus.refunded):
        return None

    mode = await settings_svc.get_str(db, "sponsor_escrow_stage2_trigger_mode")

    if mode == "event_started":
        if not event.start_time:
            return None
        start_tz = event.start_time if event.start_time.tzinfo else event.start_time.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) < start_tz:
            return None
    elif mode == "ticket_percent":
        threshold = await settings_svc.get_int(db, "sponsor_escrow_stage2_ticket_percent")
        pct = await _ticket_sold_percent(db, event_id, event.max_capacity)
        if pct < threshold:
            return None
    else:
        return None

    result = await release_stage2(db, event_id=event_id, released_by="system")
    try:
        from app.worker.redis_pool import enqueue
        await enqueue("process_escrow_release", escrow_type="sponsor", escrow_id=result.id, stage=2)
    except Exception:
        pass
    return result


async def check_and_release_stage3(db: AsyncSession, *, event_id: int) -> SponsorEscrow | None:
    """Stage 3: N days after event (or sponsor confirmed)."""
    if not await settings_svc.get_bool(db, "sponsor_escrow_stage3_trigger_enabled"):
        return None

    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        return None

    escrow = await get_or_create(db, event_id=event_id)
    if escrow.stage3_released_at or not escrow.stage2_released_at:
        return None
    if escrow.status in (EscrowStatus.frozen, EscrowStatus.refunded):
        return None

    mode = await settings_svc.get_str(db, "sponsor_escrow_stage3_trigger_mode")

    if mode == "days_after_event":
        if not event.end_time:
            return None
        end_tz = event.end_time if event.end_time.tzinfo else event.end_time.replace(tzinfo=timezone.utc)
        days_after = await settings_svc.get_int(db, "sponsor_escrow_stage3_days_after_event")
        days_since = (datetime.now(timezone.utc) - end_tz).total_seconds() / 86400
        if days_since < days_after:
            return None
    elif mode == "sponsor_confirmed":
        pass  # Manual confirmation only -- admin releases manually
    else:
        return None

    result = await release_stage3(db, event_id=event_id, released_by="system")
    try:
        from app.worker.redis_pool import enqueue
        await enqueue("process_escrow_release", escrow_type="sponsor", escrow_id=result.id, stage=3)
    except Exception:
        pass
    return result
