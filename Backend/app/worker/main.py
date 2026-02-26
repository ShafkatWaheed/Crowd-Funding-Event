"""
ARQ worker entry point.
Run with: arq app.worker.main.WorkerSettings
"""
from arq.connections import RedisSettings

from app.config import settings
from arq.cron import cron

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
    process_escrow_release,
    process_scheduled_payouts,
    daily_reconciliation,
    check_all_ticket_escrows,
    check_all_sponsor_escrows,
)


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
        process_escrow_release,
    ]
    cron_jobs = [
        cron(mock_auto_settle, second={0, 10, 20, 30, 40, 50}),
        cron(check_all_ticket_escrows, minute={0, 15, 30, 45}),
        cron(check_all_sponsor_escrows, minute={5, 20, 35, 50}),
        cron(process_scheduled_payouts, hour={0}, minute={0}),
        cron(daily_reconciliation, hour={2}, minute={0}),
    ]
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    max_jobs = 20
    job_timeout = 300
    retry_jobs = True
    max_tries = 3
