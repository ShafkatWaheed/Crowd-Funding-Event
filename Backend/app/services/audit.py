"""Admin audit log service."""
from app.logger import get_logger
from sqlalchemy.ext.asyncio import AsyncSession

logger = get_logger("audit")

from app.models.audit_log import AuditLog
from app.repositories.admin_repo import admin_repo


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
    await admin_repo.create_audit_log(db, entry)
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
    return await admin_repo.list_audit_logs(
        db, offset=offset, limit=limit,
        action=action, target_type=target_type, admin_id=admin_id,
    )
