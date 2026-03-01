"""
Platform settings service: get / set / list settings.
Casts values to int where needed. All values stored as strings.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.cache import cache_get, cache_set, cache_delete, safe_cache_key
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
    "cache_ttl_cities": 600,
    "cache_ttl_genres": 3600,
    "cache_ttl_map": 45,
    "cache_ttl_admin_dashboard": 30,
    # Cache stampede prevention (PER + SETNX)
    "cache_stampede_lock_ttl": 5,
    "cache_stampede_retry_ms": 100,
    "cache_beta_featured": 2.0,
    "cache_beta_event_detail": 1.0,
    "cache_beta_map": 1.5,
    "cache_beta_dashboard": 1.0,
    # Cache circuit breaker
    "cache_circuit_breaker_threshold": 5,
    "cache_circuit_breaker_cooldown": 30,
    # Client-side / offline sync
    "offline_scan_enabled": "true",
    "offline_scan_max_queue": 500,
    "offline_scan_sync_interval": 30,
    "client_event_cache_max_age_hours": 24,
    "client_sync_on_launch": "true",
    # ── Mock toggles ──
    "payment_mock_enabled": "true",
    "email_mock_enabled": "true",
    # Mock payment latency (ms)
    # ARQ worker cron toggles
    "arq_mock_auto_settle_enabled": "true",
    "arq_ticket_escrow_check_enabled": "true",
    "arq_sponsor_escrow_check_enabled": "true",
    "arq_scheduled_payouts_enabled": "true",
    "arq_daily_reconciliation_enabled": "true",
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
    # ── File upload limits ──
    "upload_max_image_size_mb": 10,
    "upload_max_document_size_mb": 25,
    "upload_allowed_image_types": "image/jpeg,image/png,image/webp,image/gif",
    "upload_allowed_document_types": "application/pdf,image/jpeg,image/png,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    # ── Platform holding account (encrypted values stored separately) ──
    "platform_holding_configured": "false",
    # ── Infrastructure ──
    "worker_run_log_retention_days": 30,
    "notification_retention_days": 90,
    "device_token_retention_days": 30,
    "cron_reconciliation_hour": 2,
    "cron_payout_hour": 0,
    "cron_escrow_check_interval_min": 15,
    # ── Financial Policy ──
    "payout_minimum_cents": 1000,
    "max_events_per_organizer": 50,
    "escrow_trust_score_threshold": 80,
    "max_dispute_days_after_event": 30,
    "max_push_notifications_per_hour": 100,
    "email_digest_enabled": "false",
    # ── Email Branding ──
    "email_template_logo_url": "",
    "email_template_footer_text": "You received this email because of your activity on CrowdFund Event.",
    # ── Event Limits (ceilings for per-event organizer settings) ──
    "waitlist_max_size_limit": 500,
    "waitlist_auto_approve_default": "true",
    "event_max_images_limit": 20,
    "max_posts_per_event_limit": 10,
    "max_co_organizers_limit": 10,
    "refund_deadline_percent_min": 10,
    "refund_deadline_percent_max": 50,
    # ── Sponsor delegates ──
    "max_sponsor_delegates_per_ticket": 5,
    # ── Bank verification ──
    "bank_verification_delay_seconds": 10,
    "bank_encryption_key": "",
    # ── KYC (Know Your Customer) ──
    "kyc_required_organizer": "false",
    "kyc_required_customer": "false",
    "kyc_required_sponsor": "false",
    "kyc_mock_enabled": "true",
    "mock_kyc_latency_min_ms": 500,
    "mock_kyc_latency_max_ms": 2000,
    "mock_kyc_failure_rate_percent": 0,
    # ── Chat (Sponsor negotiation) ──
    "chat_enabled": "true",
    "chat_max_message_length": 2000,
    "chat_stream_maxlen": 500,
    "chat_archive_retention_days": 30,
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

    # ── Stripe integration ──
    "stripe_enabled": "false",
    "stripe_publishable_key": "",
    "stripe_secret_key": "",
    "stripe_webhook_secret": "",
    "stripe_connect_enabled": "false",
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
    "cache_enabled": "Master on/off switch for server-side caching. When OFF every request hits the database directly, which is slower but guarantees real-time data.",
    "cache_ttl_settings": "How long platform settings are cached before refreshing from the database (seconds). Lower = settings changes take effect faster.",
    "cache_ttl_featured": "How long the Featured Events section stays cached (seconds). A short TTL keeps the homepage fresh; a long TTL reduces server load.",
    "cache_ttl_event_detail": "How long an individual event page stays cached (seconds). Shorter means attendees see updates sooner.",
    "cache_ttl_dashboard": "How long the organizer dashboard stats stay cached (seconds). Keeps repeated dashboard views snappy.",
    "cache_ttl_cities": "How long the cities dropdown list is cached (seconds). Cities change rarely, so a longer TTL (e.g. 600) is fine.",
    "cache_ttl_genres": "How long the genres list is cached (seconds). Genres almost never change, so this can be high (e.g. 3600).",
    "cache_ttl_map": "How long map marker data is cached (seconds). Shorter keeps the map accurate; longer reduces load during high traffic.",
    "cache_ttl_admin_dashboard": "How long admin dashboard statistics stay cached (seconds). Balance between freshness and query cost.",
    "cache_stampede_lock_ttl": "When the cache is empty and many users request the same data simultaneously, only one request rebuilds it. This controls how many seconds that lock is held before others can retry.",
    "cache_stampede_retry_ms": "How long other requests wait (milliseconds) before retrying when one request is already rebuilding the cache. Lower = more responsive but more retries.",
    "cache_beta_featured": "Controls how aggressively featured events are refreshed before the cache expires. Higher values (e.g. 2.0) refresh earlier, keeping data fresher at the cost of more rebuilds.",
    "cache_beta_event_detail": "Controls how aggressively event detail pages are refreshed before cache expires. 1.0 is a balanced default.",
    "cache_beta_map": "Controls how aggressively map markers are refreshed before cache expires. 1.5 is slightly more eager than default.",
    "cache_beta_dashboard": "Controls how aggressively dashboard stats are refreshed before cache expires. 1.0 is a balanced default.",
    "cache_circuit_breaker_threshold": "If the cache server (Redis) fails this many times in a row, stop trying and go directly to the database. Prevents slow responses when Redis is down.",
    "cache_circuit_breaker_cooldown": "After the circuit breaker trips, wait this many seconds before trying Redis again. Gives the cache server time to recover.",
    "offline_scan_enabled": "Allow ticket scanners to work without internet. The app downloads ticket data ahead of time and syncs scans when connectivity returns.",
    "offline_scan_max_queue": "Maximum number of offline scans a device can queue before it must sync. Prevents memory issues on devices with prolonged offline use.",
    "offline_scan_sync_interval": "How often (seconds) the app tries to push queued offline scans to the server once internet is available.",
    "client_event_cache_max_age_hours": "How many hours before locally stored event data is considered too old to show. After this, the app requires a fresh download.",
    "client_sync_on_launch": "Automatically refresh cached event data every time the app opens. Turn off to reduce server load at the cost of potentially stale offline data.",
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
    "arq_mock_auto_settle_enabled": "Enable mock auto-settle cron job (settles pending mock ledger entries periodically)",
    "arq_ticket_escrow_check_enabled": "Enable ticket escrow auto-release cron job (checks and releases ticket escrow stages every 15 min)",
    "arq_sponsor_escrow_check_enabled": "Enable sponsor escrow auto-release cron job (checks and releases sponsor escrow stages every 15 min)",
    "arq_scheduled_payouts_enabled": "Enable scheduled payouts cron job (processes organizer payouts daily at midnight)",
    "arq_daily_reconciliation_enabled": "Enable daily reconciliation cron job (runs ledger reconciliation at 2 AM)",
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
    "upload_max_image_size_mb": "Max image upload size in MB (event images, schedule images)",
    "upload_max_document_size_mb": "Max document upload size in MB (prerequisite documents)",
    "upload_allowed_image_types": "Comma-separated MIME types allowed for image uploads (e.g. image/jpeg,image/png)",
    "upload_allowed_document_types": "Comma-separated MIME types allowed for document uploads (e.g. application/pdf,image/jpeg)",
    "bank_encryption_key": "Fernet encryption key for bank account data (base64-url-safe 32 bytes). Changing this invalidates all existing encrypted bank data.",
    "platform_holding_configured": "Whether platform holding bank account is configured",
    "worker_run_log_retention_days": "Days to keep ARQ worker run log entries before auto-purge",
    "notification_retention_days": "Days to keep notification records before auto-purge",
    "device_token_retention_days": "Days to keep device tokens before auto-purge (catches orphaned tokens from failed logouts, app uninstalls, or force-quits)",
    "cron_reconciliation_hour": "Hour (0-23) for daily reconciliation cron job (takes effect on worker restart)",
    "cron_payout_hour": "Hour (0-23) for scheduled payouts cron job (takes effect on worker restart)",
    "cron_escrow_check_interval_min": "Minutes between escrow check cron runs (takes effect on worker restart)",
    "payout_minimum_cents": "Minimum balance (cents) before a payout is processed (e.g. 1000 = $10)",
    "max_events_per_organizer": "Maximum number of active events an organizer can have",
    "escrow_trust_score_threshold": "Trust score (0-100) above which organizers get bonus stage-1 release percentage",
    "max_dispute_days_after_event": "Maximum days after event end that disputes can be filed",
    "max_push_notifications_per_hour": "Maximum push notifications sent to a single user per hour",
    "email_digest_enabled": "Enable email digest mode (batch notifications into periodic digests)",
    "email_template_logo_url": "Custom logo URL for email header (empty = text-only header)",
    "email_template_footer_text": "Footer text shown in all outgoing emails",
    "waitlist_max_size_limit": "Platform-wide ceiling for per-event waitlist max size",
    "waitlist_auto_approve_default": "Default waitlist auto-approve behavior for new events",
    "event_max_images_limit": "Platform-wide ceiling for max images per event",
    "max_posts_per_event_limit": "Platform-wide ceiling for max posts per event per day",
    "max_co_organizers_limit": "Platform-wide ceiling for max co-organizers per event",
    "refund_deadline_percent_min": "Minimum allowed refund deadline percentage of funding duration",
    "refund_deadline_percent_max": "Maximum allowed refund deadline percentage of funding duration",
    "kyc_required_organizer": "Require KYC verification for organizers before creating events",
    "kyc_required_customer": "Require KYC verification for customers before purchasing tickets",
    "kyc_required_sponsor": "Require KYC verification for sponsors before placing bids",
    "kyc_mock_enabled": "Enable mock KYC verification (auto-approve; disable for manual admin review)",
    "mock_kyc_latency_min_ms": "Min simulated KYC verification latency (ms)",
    "mock_kyc_latency_max_ms": "Max simulated KYC verification latency (ms)",
    "mock_kyc_failure_rate_percent": "% of mock KYC verifications that randomly fail (0 = none)",
    "chat_enabled": "Enable sponsor-organizer negotiation chat feature",
    "chat_max_message_length": "Max characters per chat message",
    "chat_stream_maxlen": "Max messages retained per bid chat in Redis (older trimmed)",
    "chat_archive_retention_days": "Days to keep archived chat files before permanent deletion",
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

    # ── Stripe integration ──
    "stripe_enabled": "Enable Stripe as the payment gateway (disables mock and local banking)",
    "stripe_publishable_key": "Stripe publishable key (pk_test_... or pk_live_...)",
    "stripe_secret_key": "Stripe secret key (sk_test_... or sk_live_...)",
    "stripe_webhook_secret": "Stripe webhook signing secret (whsec_...)",
    "stripe_connect_enabled": "Enable Stripe Connect for organizer payouts (replaces manual bank accounts)",
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
    cache_key = safe_cache_key("settings", key)
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
    await cache_delete(safe_cache_key("settings", key))
    if key == "bank_encryption_key":
        from app.services.encryption import set_key as _set_enc_key
        _set_enc_key(value)
    elif key == "cache_enabled":
        from app.cache import set_cache_enabled
        set_cache_enabled(value.lower() == "true")
    elif key in ("cache_circuit_breaker_threshold", "cache_circuit_breaker_cooldown"):
        from app.cache import configure_circuit_breaker
        threshold = int(value) if key == "cache_circuit_breaker_threshold" else DEFAULTS["cache_circuit_breaker_threshold"]
        cooldown = int(value) if key == "cache_circuit_breaker_cooldown" else DEFAULTS["cache_circuit_breaker_cooldown"]
        # Re-read both values to get the current pair
        t_raw = await _get_raw(db, "cache_circuit_breaker_threshold")
        c_raw = await _get_raw(db, "cache_circuit_breaker_cooldown")
        configure_circuit_breaker(
            threshold=int(t_raw) if t_raw else DEFAULTS["cache_circuit_breaker_threshold"],
            cooldown=int(c_raw) if c_raw else DEFAULTS["cache_circuit_breaker_cooldown"],
        )
    return row
