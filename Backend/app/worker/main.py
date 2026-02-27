"""
ARQ worker entry point.
Run with: arq app.worker.main.WorkerSettings
"""
from arq.connections import RedisSettings
from arq.cron import cron

from app.config import settings
from app.logger import setup_logging, get_logger

setup_logging(settings.LOG_LEVEL)
logger = get_logger("arq.main")

from app.worker.tasks import (
    process_pledge_refund,
    process_bulk_pledge_refunds,
    process_ticket_refund,
    process_sponsor_refund,
    process_bulk_sponsor_refunds,
    send_event_cancelled_email,
    send_ticket_purchased_email,
    send_waitlist_rejected_email,
    send_ticket_refund_approved_email,
    send_waitlist_approved_email,
    send_sponsor_bid_approved_email,
    send_sponsor_bid_rejected_email,
    send_sponsor_refund_email,
    mock_auto_settle,
    mock_verify_bank_account,
    process_escrow_release,
    process_scheduled_payouts,
    daily_reconciliation,
    check_all_ticket_escrows,
    check_all_sponsor_escrows,
    cleanup_old_records,
    archive_resolved_chats,
    purge_old_chat_archives,
)


def _load_cron_config() -> dict:
    """Load cron scheduling config from DB at worker boot, falling back to defaults."""
    from app.services.platform_settings import DEFAULTS
    defaults = {
        "recon_h": int(DEFAULTS["cron_reconciliation_hour"]),
        "payout_h": int(DEFAULTS["cron_payout_hour"]),
        "escrow_min": int(DEFAULTS["cron_escrow_check_interval_min"]),
    }
    try:
        import asyncio
        from app.db.base import async_session_factory
        from app.services import platform_settings as s

        async def _read():
            async with async_session_factory() as db:
                return {
                    "recon_h": await s.get_int(db, "cron_reconciliation_hour"),
                    "payout_h": await s.get_int(db, "cron_payout_hour"),
                    "escrow_min": await s.get_int(db, "cron_escrow_check_interval_min"),
                }
        return asyncio.get_event_loop().run_until_complete(_read())
    except Exception:
        logger.warning("Could not load cron config from DB, using defaults")
        return defaults


def _build_cron_jobs():
    cfg = _load_cron_config()
    interval = max(1, cfg["escrow_min"])
    mins = set(range(0, 60, interval))
    offset_mins = {(m + 5) % 60 for m in mins}
    return [
        cron(mock_auto_settle, second={0, 10, 20, 30, 40, 50}),
        cron(check_all_ticket_escrows, minute=mins),
        cron(check_all_sponsor_escrows, minute=offset_mins),
        cron(process_scheduled_payouts, hour={cfg["payout_h"]}, minute={0}),
        cron(daily_reconciliation, hour={cfg["recon_h"]}, minute={0}),
        cron(cleanup_old_records, hour={3}, minute={30}),
        cron(archive_resolved_chats, hour={3}, minute={0}),
        cron(purge_old_chat_archives, hour={3}, minute={45}),
    ]


class WorkerSettings:
    functions = [
        process_pledge_refund,
        process_bulk_pledge_refunds,
        process_ticket_refund,
        process_sponsor_refund,
        process_bulk_sponsor_refunds,
        send_event_cancelled_email,
        send_ticket_purchased_email,
        send_waitlist_rejected_email,
        send_ticket_refund_approved_email,
        send_waitlist_approved_email,
        send_sponsor_bid_approved_email,
        send_sponsor_bid_rejected_email,
        send_sponsor_refund_email,
        mock_verify_bank_account,
        process_escrow_release,
        cleanup_old_records,
        archive_resolved_chats,
        purge_old_chat_archives,
    ]
    cron_jobs = _build_cron_jobs()
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    max_jobs = 20
    job_timeout = 300
    retry_jobs = True
    max_tries = 3
