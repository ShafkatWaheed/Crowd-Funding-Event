"""
Platform settings service: get / set / list settings.
Casts values to int where needed. All values stored as strings.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.models.platform_settings import PlatformSetting

# Default values used when key not yet in DB
DEFAULTS = {
    "ticket_commission_percent": 5,
    "funding_commission_percent": 3,
    "cancel_approval_threshold_percent": 80,
    "event_date_grace_days": 7,
    # Feature flags (boolean, stored as "true"/"false")
    "feature_milestones_enabled": "true",
    "feature_schedule_enabled": "true",
    "feature_sponsors_enabled": "true",
}


async def get_all(db: AsyncSession) -> dict[str, str]:
    """Return all settings as {key: value}."""
    q = select(PlatformSetting).order_by(PlatformSetting.key)
    rows = (await db.execute(q)).scalars().all()
    return {r.key: r.value for r in rows}


async def get_all_with_descriptions(db: AsyncSession) -> list[dict]:
    """Return all settings with descriptions for admin UI."""
    q = select(PlatformSetting).order_by(PlatformSetting.key)
    rows = (await db.execute(q)).scalars().all()
    return [{"key": r.key, "value": r.value, "description": r.description} for r in rows]


async def get_int(db: AsyncSession, key: str) -> int:
    """Get a setting as integer. Falls back to DEFAULTS if missing."""
    q = select(PlatformSetting).where(PlatformSetting.key == key)
    row = (await db.execute(q)).scalar_one_or_none()
    if row is None:
        return DEFAULTS.get(key, 0)
    return int(row.value)


async def get_bool(db: AsyncSession, key: str) -> bool:
    """Get a setting as boolean. Falls back to DEFAULTS if missing."""
    q = select(PlatformSetting).where(PlatformSetting.key == key)
    row = (await db.execute(q)).scalar_one_or_none()
    if row is None:
        return str(DEFAULTS.get(key, "false")).lower() == "true"
    return row.value.lower() == "true"


async def get_str(db: AsyncSession, key: str) -> str | None:
    """Get a setting as string. Returns None if missing."""
    q = select(PlatformSetting).where(PlatformSetting.key == key)
    row = (await db.execute(q)).scalar_one_or_none()
    return row.value if row else None


async def set_value(db: AsyncSession, key: str, value: str, description: str | None = None) -> PlatformSetting:
    """Upsert a setting. Creates if missing, updates if exists."""
    q = select(PlatformSetting).where(PlatformSetting.key == key)
    row = (await db.execute(q)).scalar_one_or_none()
    if row:
        row.value = value
        if description is not None:
            row.description = description
        await db.flush()
        await db.refresh(row)
        return row
    row = PlatformSetting(key=key, value=value, description=description)
    db.add(row)
    await db.flush()
    await db.refresh(row)
    return row
