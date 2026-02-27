"""Admin audit log service."""
from sqlalchemy import func, select

from app.logger import get_logger
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_log import AuditLog


async def log_action(
    db: AsyncSession,
    *,
    admin_id: int,
    action: str,
    target_type: str,
    target_id: str | int | None = None,
    details: dict | None = None,
) -> AuditLog:
    logger.debug("Audit entry creation", extra={"admin_id": admin_id, "action": action, "target_type": target_type, "target_id": target_id})
    entry = AuditLog(
        admin_id=admin_id,
        action=action,
        target_type=target_type,
        target_id=str(target_id) if target_id is not None else None,
        details=details,
    )
    db.add(entry)
    await db.flush()
    return entry


async def list_audit_logs(
    db: AsyncSession,
    *,
    offset: int = 0,
    limit: int = 50,
    action: str | None = None,
    target_type: str | None = None,
    admin_id: int | None = None,
) -> tuple[list[AuditLog], int]:
    q = select(AuditLog)
    if action:
        q = q.where(AuditLog.action == action)
    if target_type:
        q = q.where(AuditLog.target_type == target_type)
    if admin_id:
        q = q.where(AuditLog.admin_id == admin_id)

    total = (await db.execute(
        select(func.count()).select_from(q.subquery())
    )).scalar_one()

    rows = (await db.execute(
        q.order_by(AuditLog.created_at.desc()).offset(offset).limit(limit)
    )).scalars().all()

    return list(rows), int(total)
