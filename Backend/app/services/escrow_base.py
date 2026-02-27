"""
Shared escrow operations used by fund, ticket, and sponsor escrow services.

Each service still provides its own get_or_create (different total calculation),
auto-trigger logic, and refresh_total. This module reduces duplication for
freeze, unfreeze, release_stage, and list_all.
"""
from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.escrow import EscrowStatus
from app.models.event import Event
from app.models.user import User


def reject_if_frozen(escrow, *, label: str = "Escrow") -> None:
    if escrow.status == EscrowStatus.frozen:
        raise ConflictError(f"{label} is frozen")


async def generic_freeze(db: AsyncSession, model_class, *, event_id: int, get_or_create_fn):
    escrow = await get_or_create_fn(db, event_id=event_id)
    escrow.status = EscrowStatus.frozen
    await db.flush()
    return escrow


async def generic_unfreeze(db: AsyncSession, model_class, *, event_id: int, get_or_create_fn, label: str = "Escrow"):
    escrow = await get_or_create_fn(db, event_id=event_id)
    if escrow.status != EscrowStatus.frozen:
        raise ConflictError(f"{label} is not frozen")
    if escrow.stage3_released_at:
        escrow.status = EscrowStatus.fully_released
    elif escrow.stage1_released_at:
        escrow.status = EscrowStatus.partially_released
    else:
        escrow.status = EscrowStatus.holding
    await db.flush()
    return escrow


async def generic_release_stage(
    db: AsyncSession,
    *,
    event_id: int,
    stage: int,
    settings_key: str,
    get_or_create_fn,
    reject_fn,
    released_by: str = "system",
    label: str = "Escrow",
):
    """Release a stage for any escrow type.

    Args:
        settings_key: the platform settings key for the percentage (e.g. 'ticket_escrow_stage1_percent')
        reject_fn: callable(escrow) that raises if blocked
    """
    from app.services import platform_settings as settings_svc

    escrow = await get_or_create_fn(db, event_id=event_id)

    stage_released_at = getattr(escrow, f"stage{stage}_released_at")
    if stage_released_at:
        raise ConflictError(f"{label} Stage {stage} already released")

    if stage > 1:
        prev = getattr(escrow, f"stage{stage - 1}_released_at")
        if not prev:
            raise ConflictError(f"{label} Stage {stage - 1} must be released first")

    reject_fn(escrow)

    pct = await settings_svc.get_int(db, settings_key)
    amount = escrow.total_held_cents * pct // 100
    now = datetime.now(timezone.utc)

    setattr(escrow, f"stage{stage}_released_cents", amount)
    setattr(escrow, f"stage{stage}_released_at", now)

    if stage == 3:
        escrow.status = EscrowStatus.fully_released
    else:
        escrow.status = EscrowStatus.partially_released

    await db.flush()
    await db.refresh(escrow)
    return escrow


async def generic_list_all(
    db: AsyncSession,
    model_class,
    *,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
) -> tuple[list[dict], int]:
    """Paginated list of escrows with event + organizer info."""
    base = (
        select(
            model_class,
            Event.title.label("event_title"),
            User.display_name.label("organizer_name"),
            User.email.label("organizer_email"),
        )
        .join(Event, model_class.event_id == Event.id)
        .join(User, Event.organizer_id == User.id)
    )
    if search:
        filters = [Event.title.ilike(f"%{search}%")]
        try:
            filters.append(model_class.event_id == int(search))
        except ValueError:
            pass
        base = base.where(or_(*filters))

    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one()
    rows = (await db.execute(
        base.order_by(model_class.updated_at.desc()).offset(offset).limit(limit)
    )).all()

    result = []
    for row in rows:
        e = row[0]
        released = e.stage1_released_cents + e.stage2_released_cents + e.stage3_released_cents
        result.append({
            "id": e.id,
            "event_id": e.event_id,
            "event_title": row.event_title,
            "organizer_name": row.organizer_name,
            "organizer_email": row.organizer_email,
            "total_held_cents": e.total_held_cents,
            "total_released_cents": released,
            "remaining_cents": max(0, e.total_held_cents - released),
            "status": e.status.value,
            "stage1_released_at": e.stage1_released_at.isoformat() if e.stage1_released_at else None,
            "stage2_released_at": e.stage2_released_at.isoformat() if e.stage2_released_at else None,
            "stage3_released_at": e.stage3_released_at.isoformat() if e.stage3_released_at else None,
        })
    return result, int(total)
