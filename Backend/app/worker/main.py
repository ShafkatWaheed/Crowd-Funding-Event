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
)


class WorkerSettings:
    functions = [
        process_pledge_refund,
        process_bulk_pledge_refunds,
        process_ticket_refund,
        process_sponsor_refund,
        process_bulk_sponsor_refunds,
    ]
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    max_jobs = 20
    job_timeout = 300
    retry_jobs = True
    max_tries = 3
