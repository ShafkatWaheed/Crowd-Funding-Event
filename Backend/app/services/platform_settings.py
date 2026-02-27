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
    "push_notifications_enabled": "true",
    "sponsor_commission_percent": 5,
    # Cache
    "cache_enabled": "true",
    # Cache TTLs (seconds)
    "cache_ttl_settings": 300,
    "cache_ttl_featured": 60,
    "cache_ttl_event_detail": 30,
    "cache_ttl_dashboard": 15,
    # ── Mock toggles ──
    "payment_mock_enabled": "true",
    "email_mock_enabled": "true",
    # Mock payment latency (ms)
    "mock_charge_latency_min_ms": 800,
    "mock_charge_latency_max_ms": 3000,
    "mock_transfer_latency_min_ms": 1000,
    "mock_transfer_latency_max_ms": 5000,
    "mock_refund_latency_min_ms": 2000,
    "mock_refund_latency_max_ms": 7000,
    # Mock failure simulation
    "mock_failure_rate_percent": 0,
    "mock_fail_next_charge": "false",
    # Mock settlement
    "mock_settlement_delay_seconds": 30,
    # Mock Stripe fee simulation
    "mock_stripe_fee_percent": 2.9,
    "mock_stripe_fee_fixed_cents": 30,
    # Mock email simulation
    "mock_email_bounce_rate_percent": 0,
    # ── Ticket escrow settings ──
    "ticket_escrow_stage1_percent": 30,
    "ticket_escrow_stage1_days_after_event": 3,
    "ticket_escrow_stage2_percent": 40,
    "ticket_escrow_stage2_days_after_event": 14,
    "ticket_escrow_stage2_max_refund_rate": 10,
    "ticket_escrow_stage3_percent": 30,
    "ticket_escrow_stage3_days_after_event": 30,
    "ticket_escrow_stage3_require_no_disputes": "true",
    # ── Sponsor escrow settings ──
    "sponsor_escrow_stage1_percent": 30,
    "sponsor_escrow_stage1_trigger_enabled": "true",
    "sponsor_escrow_stage1_trigger_mode": "event_live",
    "sponsor_escrow_stage1_days_before_event": 14,
    "sponsor_escrow_stage2_percent": 40,
    "sponsor_escrow_stage2_trigger_enabled": "true",
    "sponsor_escrow_stage2_trigger_mode": "event_started",
    "sponsor_escrow_stage2_ticket_percent": 60,
    "sponsor_escrow_stage3_percent": 30,
    "sponsor_escrow_stage3_trigger_enabled": "true",
    "sponsor_escrow_stage3_trigger_mode": "days_after_event",
    "sponsor_escrow_stage3_days_after_event": 14,
    # ── Tax settings ──
    "tax_enabled": "false",
    "default_tax_rate": 0.0,
    "default_tax_jurisdiction": "",
    "tax_applies_to_tickets": "true",
    "tax_applies_to_sponsors": "true",
    "tax_applies_to_pledges": "false",
    # ── Email config (stored in platform settings, overridable from env) ──
    "email_enabled": "false",
    "email_provider": "console",
    "email_from_address": "",
    "email_from_name": "",
    # ── Platform holding account (encrypted values stored separately) ──
    "platform_holding_configured": "false",
    # ── API rate limits (format: "N/minute", "N/second", or "N/hour") ──
    "rate_limit_global_default": "120/minute",
    "rate_limit_auth_verify": "10/minute",
    "rate_limit_public_config": "60/minute",
    "rate_limit_event_register": "20/minute",
    "rate_limit_ticket_purchase": "15/minute",
    "rate_limit_pledge": "20/minute",
    "rate_limit_file_upload": "10/minute",
    "rate_limit_payment_action": "10/minute",
    "rate_limit_event_create": "5/minute",
    "rate_limit_content_create": "15/minute",
    "rate_limit_public_search": "60/minute",
    "rate_limit_social_action": "30/minute",
    "rate_limit_qr_scan": "30/minute",
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
    "push_notifications_enabled": "Enable FCM push notifications to user devices (true = send push alongside in-app notifications)",
    "cache_enabled": "Master toggle for Redis caching (true = enabled, false = disabled, all reads become DB-direct)",
    "cache_ttl_settings": "Redis cache TTL for platform settings (seconds)",
    "cache_ttl_featured": "Redis cache TTL for featured events endpoint (seconds)",
    "cache_ttl_event_detail": "Redis cache TTL for event detail endpoint (seconds)",
    "cache_ttl_dashboard": "Redis cache TTL for organizer dashboard endpoint (seconds)",
    "payment_mock_enabled": "Enable mock payment gateway (all payments simulated)",
    "email_mock_enabled": "Enable mock email backend (all emails logged to console)",
    "mock_charge_latency_min_ms": "Min simulated charge latency (ms)",
    "mock_charge_latency_max_ms": "Max simulated charge latency (ms)",
    "mock_transfer_latency_min_ms": "Min simulated transfer latency (ms)",
    "mock_transfer_latency_max_ms": "Max simulated transfer latency (ms)",
    "mock_refund_latency_min_ms": "Min simulated refund latency (ms)",
    "mock_refund_latency_max_ms": "Max simulated refund latency (ms)",
    "mock_failure_rate_percent": "% of mock charges that randomly fail (0 = none)",
    "mock_fail_next_charge": "Force the next charge to fail (one-shot toggle)",
    "mock_settlement_delay_seconds": "Seconds before settlement completes in mock mode",
    "mock_stripe_fee_percent": "Simulated Stripe fee percentage (e.g. 2.9)",
    "mock_stripe_fee_fixed_cents": "Simulated Stripe fixed fee per charge (cents)",
    "mock_email_bounce_rate_percent": "% of mock emails that simulate bounce (0 = none)",
    "ticket_escrow_stage1_percent": "Ticket escrow Stage 1 release percentage",
    "ticket_escrow_stage1_days_after_event": "Days after event to release ticket escrow Stage 1",
    "ticket_escrow_stage2_percent": "Ticket escrow Stage 2 release percentage",
    "ticket_escrow_stage2_days_after_event": "Days after event to release ticket escrow Stage 2",
    "ticket_escrow_stage2_max_refund_rate": "Max refund rate (%) to allow ticket escrow Stage 2",
    "ticket_escrow_stage3_percent": "Ticket escrow Stage 3 release percentage",
    "ticket_escrow_stage3_days_after_event": "Days after event to release ticket escrow Stage 3",
    "ticket_escrow_stage3_require_no_disputes": "Require no open disputes for ticket escrow Stage 3",
    "sponsor_escrow_stage1_percent": "Sponsor escrow Stage 1 release percentage",
    "sponsor_escrow_stage1_trigger_enabled": "Auto-release sponsor escrow Stage 1",
    "sponsor_escrow_stage1_trigger_mode": "Trigger mode for sponsor escrow Stage 1 (event_live, days_before_event)",
    "sponsor_escrow_stage1_days_before_event": "Days before event to trigger sponsor escrow Stage 1",
    "sponsor_escrow_stage2_percent": "Sponsor escrow Stage 2 release percentage",
    "sponsor_escrow_stage2_trigger_enabled": "Auto-release sponsor escrow Stage 2",
    "sponsor_escrow_stage2_trigger_mode": "Trigger mode for sponsor escrow Stage 2 (event_started, ticket_percent)",
    "sponsor_escrow_stage2_ticket_percent": "Ticket sales % to trigger sponsor escrow Stage 2",
    "sponsor_escrow_stage3_percent": "Sponsor escrow Stage 3 release percentage",
    "sponsor_escrow_stage3_trigger_enabled": "Auto-release sponsor escrow Stage 3",
    "sponsor_escrow_stage3_trigger_mode": "Trigger mode for sponsor escrow Stage 3 (days_after_event, sponsor_confirmed)",
    "sponsor_escrow_stage3_days_after_event": "Days after event to trigger sponsor escrow Stage 3",
    "tax_enabled": "Enable tax collection on transactions",
    "default_tax_rate": "Default tax rate (e.g. 0.0825 for 8.25%)",
    "default_tax_jurisdiction": "Default tax jurisdiction code (e.g. US-TX)",
    "tax_applies_to_tickets": "Apply tax to ticket sales",
    "tax_applies_to_sponsors": "Apply tax to sponsor payments",
    "tax_applies_to_pledges": "Apply tax to pledge/funding",
    "email_enabled": "Enable email sending",
    "email_provider": "Email provider (console, sendgrid)",
    "email_from_address": "Email From address",
    "email_from_name": "Email From display name",
    "platform_holding_configured": "Whether platform holding bank account is configured",
    "rate_limit_global_default": "Global default rate limit for all endpoints without a specific limit (e.g. 120/minute)",
    "rate_limit_auth_verify": "Rate limit for POST /auth/verify (e.g. 10/minute)",
    "rate_limit_public_config": "Rate limit for GET /config (e.g. 60/minute)",
    "rate_limit_event_register": "Rate limit for POST /events/{id}/register (e.g. 20/minute)",
    "rate_limit_ticket_purchase": "Rate limit for POST /events/{id}/purchase-ticket (e.g. 15/minute)",
    "rate_limit_pledge": "Rate limit for POST /events/{id}/pledge (e.g. 20/minute)",
    "rate_limit_file_upload": "Rate limit for all file upload endpoints (e.g. 10/minute)",
    "rate_limit_payment_action": "Rate limit for payment/refund actions (e.g. 10/minute)",
    "rate_limit_event_create": "Rate limit for event creation and cloning (e.g. 5/minute)",
    "rate_limit_content_create": "Rate limit for posts and ratings creation (e.g. 15/minute)",
    "rate_limit_public_search": "Rate limit for public search/discovery endpoints (e.g. 60/minute)",
    "rate_limit_social_action": "Rate limit for reactions and bookmarks (e.g. 30/minute)",
    "rate_limit_qr_scan": "Rate limit for ticket/sponsor QR scanning (e.g. 30/minute)",
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


async def get_float(db: AsyncSession, key: str) -> float:
    """Get a setting as float. Falls back to DEFAULTS if missing."""
    raw = await _get_raw(db, key)
    if raw is None:
        return float(DEFAULTS.get(key, 0.0))
    return float(raw)


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
