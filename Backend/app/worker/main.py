"""
ARQ worker entry point.
Run with: arq app.worker.main.WorkerSettings
"""
from arq.connections import RedisSettings

from app.config import settings
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
    ]
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    max_jobs = 20
    job_timeout = 300
    retry_jobs = True
    max_tries = 3
