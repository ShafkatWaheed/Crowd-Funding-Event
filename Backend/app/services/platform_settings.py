"""
Platform settings service: get / set / list settings.
Casts values to int where needed. All values stored as strings.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.cache import cache_get, cache_set, cache_delete
from app.core.exceptions import NotFoundError
from app.models.platform_settings import PlatformSetting

# Default values used when key not yet in DB
DEFAULTS = {
    # Branding (strings; use get_str in code)
    "platform_name": "",
    "support_email": "",
    # Rate limits
    "max_tickets_per_purchase": 10,
    "max_tickets_backend_enabled": "true",
    "max_tickets_frontend_enabled": "true",
    # Refund
    "default_refund_deadline_days": 7,
    "ticket_commission_percent": 5,
    "funding_commission_percent": 3,
    "cancel_approval_threshold_percent": 80,
    "event_date_grace_days": 7,
    "event_date_deadline_days": 30,
    # Escrow: release stage percentages (must sum to 100)
    "escrow_stage1_percent": 30,
    "escrow_stage2_percent": 40,
    "escrow_stage3_percent": 30,
    "escrow_stage1_trigger_enabled": "true",
    "escrow_stage1_trigger_mode": "ticket_percent",
    "escrow_stage1_ticket_percent": 50,
    "escrow_stage2_trigger_enabled": "true",
    "escrow_stage2_trigger_mode": "days_percent",
    "escrow_stage2_ticket_percent": 75,
    "escrow_stage2_days_percent": 50,
    "escrow_stage3_trigger_enabled": "true",
    "escrow_stage3_trigger_mode": "days_after",
    "escrow_stage3_days_after_event": 7,
    "scan_threshold_percent": 50,
    "stage3_grace_days": 14,
    # Community / organizer
    "community_max_duration_days": 14,
    "community_max_ticket_price_cents": 5000,
    "community_listing_fee_cents": 1000,
    "community_ticket_commission_percent": "",
    "community_funding_commission_percent": "",
    "community_sponsor_commission_percent": "",
    "community_escrow_disabled": "false",
    "new_organizer_deposit_cents": 5000,
    # Feature flags (boolean, stored as "true"/"false")
    "feature_milestones_enabled": "true",
    "feature_schedule_enabled": "true",
    "feature_sponsors_enabled": "true",
    "feature_community_rules_enabled": "true",
    "sponsor_commission_percent": 5,
    # Cache
    "cache_enabled": "true",
    # Cache TTLs (seconds)
    "cache_ttl_settings": 300,
    "cache_ttl_featured": 60,
    "cache_ttl_event_detail": 30,
    "cache_ttl_dashboard": 15,
}

DESCRIPTIONS = {
    "platform_name": "Platform name shown in UI and emails",
    "support_email": "Support contact email for users (UI and emails)",
    "max_tickets_per_purchase": "Max tickets per single purchase (rate limit)",
    "max_tickets_backend_enabled": "Enforce max ticket limit on the backend (API rejects purchases exceeding the limit)",
    "max_tickets_frontend_enabled": "Enforce max ticket limit on the frontend (UI prevents selecting more than the limit)",
    "default_refund_deadline_days": "Default refund deadline: X days before event start (refund eligible until then)",
    "ticket_commission_percent": "Platform commission on ticket sales (%)",
    "funding_commission_percent": "Platform commission on pledges (%)",
    "sponsor_commission_percent": "Platform commission on sponsor payments (%)",
    "cancel_approval_threshold_percent": "Pledge % above which event cancel needs admin approval",
    "event_date_grace_days": "Days allowed to set event date after approval",
    "event_date_deadline_days": "Days after goal met to set event date before auto-refund",
    "escrow_stage1_percent": "Percentage of funds released at Stage 1 (planning confirmed)",
    "escrow_stage2_percent": "Percentage of funds released at Stage 2 (event imminent)",
    "escrow_stage3_percent": "Percentage of funds released at Stage 3 (event completed)",
    "escrow_stage1_trigger_enabled": "Auto-release Stage 1 when trigger condition met. Disable for manual-only release.",
    "escrow_stage1_trigger_mode": "Trigger mode for Stage 1 (ticket_percent = X% tickets sold, funding_end = funding stage ended, selling_started = ticket selling begins)",
    "escrow_stage1_ticket_percent": "Ticket sales % of capacity to trigger Stage 1 (when mode = ticket_percent)",
    "escrow_stage2_trigger_enabled": "Auto-release Stage 2 when trigger condition met. Disable for manual-only release.",
    "escrow_stage2_trigger_mode": "Trigger mode for Stage 2 (ticket_percent = X% tickets sold, days_percent = X% of selling-to-live window elapsed)",
    "escrow_stage2_ticket_percent": "Ticket sales % of capacity to trigger Stage 2 (when mode = ticket_percent)",
    "escrow_stage2_days_percent": "% of days elapsed from selling start to event go-live to trigger Stage 2 (when mode = days_percent)",
    "escrow_stage3_trigger_enabled": "Auto-release Stage 3 after event ends. Disable for manual-only release.",
    "escrow_stage3_trigger_mode": "Trigger mode for Stage 3 (days_after = X days after event end, scan_threshold = event completed + X% tickets scanned)",
    "escrow_stage3_days_after_event": "Days after event end to auto-release Stage 3 (when mode = days_after)",
    "scan_threshold_percent": "Min % of tickets scanned at door to auto-release Stage 3 (when mode = scan_threshold)",
    "stage3_grace_days": "Days to hold Stage 3 funds for admin review",
    "community_max_duration_days": "Max total days for community events (funding + event)",
    "community_max_ticket_price_cents": "Max ticket price for community tiers (cents, e.g. 5000 = $50)",
    "community_listing_fee_cents": "Listing fee for community events (cents, e.g. 1000 = $10)",
    "community_ticket_commission_percent": "Override ticket commission % for community events (empty = use global, 0 = no commission)",
    "community_funding_commission_percent": "Override funding commission % for community events (empty = use global, 0 = no commission)",
    "community_sponsor_commission_percent": "Override sponsor commission % for community events (empty = use global, 0 = no commission)",
    "community_escrow_disabled": "Disable escrow for community events (true = skip escrow entirely)",
    "new_organizer_deposit_cents": "Deposit required from first-time organizers (cents, e.g. 5000 = $50)",
    "feature_milestones_enabled": "Enable funding milestones",
    "feature_schedule_enabled": "Enable event schedule",
    "feature_sponsors_enabled": "Enable sponsors",
    "feature_community_rules_enabled": "Allow organizers to enable community rules on new events",
    "cache_enabled": "Master toggle for Redis caching (true = enabled, false = disabled, all reads become DB-direct)",
    "cache_ttl_settings": "Redis cache TTL for platform settings (seconds)",
    "cache_ttl_featured": "Redis cache TTL for featured events endpoint (seconds)",
    "cache_ttl_event_detail": "Redis cache TTL for event detail endpoint (seconds)",
    "cache_ttl_dashboard": "Redis cache TTL for organizer dashboard endpoint (seconds)",
}


async def get_all(db: AsyncSession) -> dict[str, str]:
    """Return all settings as {key: value}."""
    q = select(PlatformSetting).order_by(PlatformSetting.key)
    rows = (await db.execute(q)).scalars().all()
    return {r.key: r.value for r in rows}


async def get_all_with_descriptions(db: AsyncSession) -> list[dict]:
    """Return all settings with descriptions for admin UI. Merges in defaults for any key not in DB."""
    q = select(PlatformSetting).order_by(PlatformSetting.key)
    rows = (await db.execute(q)).scalars().all()
    by_key = {r.key: {"key": r.key, "value": r.value, "description": r.description} for r in rows}
    result = []
    for key in sorted(set(DEFAULTS.keys()) | set(by_key.keys())):
        if key in by_key:
            result.append(by_key[key])
        else:
            result.append({
                "key": key,
                "value": str(DEFAULTS[key]),
                "description": DESCRIPTIONS.get(key),
            })
    return result


async def _get_raw(db: AsyncSession, key: str) -> str | None:
    """Fetch the raw setting value, checking Redis cache first."""
    cache_key = f"settings:{key}"
    cached = await cache_get(cache_key)
    if cached is not None:
        return cached

    q = select(PlatformSetting).where(PlatformSetting.key == key)
    row = (await db.execute(q)).scalar_one_or_none()
    if row is not None:
        await cache_set(cache_key, row.value, ttl=DEFAULTS["cache_ttl_settings"])
        return row.value
    return None


async def get_int(db: AsyncSession, key: str) -> int:
    """Get a setting as integer. Falls back to DEFAULTS if missing."""
    raw = await _get_raw(db, key)
    if raw is None:
        return DEFAULTS.get(key, 0)
    return int(raw)


async def get_bool(db: AsyncSession, key: str) -> bool:
    """Get a setting as boolean. Falls back to DEFAULTS if missing."""
    raw = await _get_raw(db, key)
    if raw is None:
        return str(DEFAULTS.get(key, "false")).lower() == "true"
    return raw.lower() == "true"


async def get_str(db: AsyncSession, key: str) -> str:
    """Get a setting as string. Falls back to DEFAULTS if missing."""
    raw = await _get_raw(db, key)
    if raw is not None:
        return raw
    default = DEFAULTS.get(key)
    return str(default) if default is not None else ""


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
    else:
        row = PlatformSetting(key=key, value=value, description=description)
        db.add(row)
        await db.flush()
        await db.refresh(row)
    await cache_delete(f"settings:{key}")
    if key == "cache_enabled":
        from app.cache import set_cache_enabled
        set_cache_enabled(value.lower() == "true")
    return row
