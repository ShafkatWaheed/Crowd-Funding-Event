"""
Shared escrow operations used by fund, ticket, and sponsor escrow services.

Each service still provides its own get_or_create (different total calculation),
auto-trigger logic, and refresh_total. This module reduces duplication for
freeze, unfreeze, release_stage, and list_all.
"""
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.escrow import EscrowRelease, EscrowStatus

from app.logger import get_logger
from app.repositories.escrow_repo import escrow_repo

logger = get_logger("escrow")


def reject_if_frozen(escrow, *, label: str = "Escrow") -> None:
    if escrow.status == EscrowStatus.frozen:
        raise ConflictError(f"{label} is frozen")


async def generic_freeze(db: AsyncSession, model_class, *, event_id: int, get_or_create_fn):
    escrow = await get_or_create_fn(db, event_id=event_id)
    await escrow_repo.update_status(db, escrow, EscrowStatus.frozen)
    return escrow


async def generic_unfreeze(db: AsyncSession, model_class, *, event_id: int, get_or_create_fn, label: str = "Escrow"):
    escrow = await get_or_create_fn(db, event_id=event_id)
    if escrow.status != EscrowStatus.frozen:
        raise ConflictError(f"{label} is not frozen")
    if escrow.stage3_released_at:
        new_status = EscrowStatus.fully_released
    elif escrow.stage1_released_at:
        new_status = EscrowStatus.partially_released
    else:
        new_status = EscrowStatus.holding
    await escrow_repo.update_status(db, escrow, new_status)

    await _warn_admins_if_no_bank(db, event_id, label=label)

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

    await escrow_repo.release_stage(db, escrow, stage=stage, amount=amount, now=now)
    await escrow_repo.flush_and_refresh(db, escrow)
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
    rows, total = await escrow_repo.list_all_admin(
        db, model_class, offset=offset, limit=limit, search=search
    )

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


# ---------------------------------------------------------------------------
# Bank account helpers
# ---------------------------------------------------------------------------

async def organizer_has_verified_bank(db: AsyncSession, organizer_id: int) -> bool:
    """True if the organizer has a bank account with verification_status='verified'."""
    return await escrow_repo.organizer_has_verified_bank(db, organizer_id)


async def get_organizer_for_event(db: AsyncSession, event_id: int) -> int | None:
    """Return the organizer_id for a given event, or None."""
    return await escrow_repo.get_organizer_for_event(db, event_id)


async def get_all_admin_ids(db: AsyncSession) -> list[int]:
    """Return IDs of all admin users."""
    return await escrow_repo.get_all_admin_ids(db)


async def _warn_admins_if_no_bank(db: AsyncSession, event_id: int, *, label: str = "Escrow") -> None:
    """After unfreezing, warn all admins if organizer has no verified bank account."""
    organizer_id = await escrow_repo.get_organizer_for_event(db, event_id)
    if organizer_id is None:
        return
    if await escrow_repo.organizer_has_verified_bank(db, organizer_id):
        return

    from app.services import notification_service as notif_svc
    from app.models.notification import NotificationType

    admin_ids = await escrow_repo.get_all_admin_ids(db)
    if admin_ids:
        await notif_svc.create_bulk_notifications(
            db, user_ids=admin_ids,
            type=NotificationType.escrow_unfreeze_warning,
            title="Escrow Unfrozen Without Bank Account",
            message=(
                f"{label} unfrozen for Event #{event_id} but the organizer "
                "does not have a verified bank account."
            ),
            data={"event_id": event_id},
        )
    logger.warning(
        "%s unfrozen for event %d without verified bank account", label, event_id,
    )


async def has_active_escrow(db: AsyncSession, organizer_id: int) -> bool:
    """True if organizer has any event with escrow in holding/partially_released."""
    return await escrow_repo.has_active_escrow(db, organizer_id)


# ---------------------------------------------------------------------------
# Rollback release (called when payout fails)
# ---------------------------------------------------------------------------

async def rollback_release(
    db: AsyncSession, escrow, *, stage: int, reason: str,
) -> None:
    """Reverse a stage release after a payout failure."""
    await escrow_repo.rollback_stage(db, escrow, stage=stage)

    log = EscrowRelease(
        escrow_id=escrow.id, stage=stage, amount_cents=0,
        released_by="system", reason=f"Rollback: {reason}",
        release_status="rolled_back",
    )
    await escrow_repo.add_release_log(db, log)
    await escrow_repo.flush(db)
    logger.warning(
        "Escrow %d stage %d rolled back: %s", escrow.id, stage, reason,
    )
