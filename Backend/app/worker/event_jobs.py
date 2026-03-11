"""
Helpers for enqueueing deferred ARQ jobs for event status transitions.

Call schedule_event_transitions(event) after any operation that sets or changes
funding_end_at, start_time, or end_time on an Event. Each job carries the date
as an idempotency token — if the date changes before the job fires, the stale
job self-terminates without making changes.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession
    from app.models.event import Event


async def schedule_event_transitions(event: "Event") -> None:
    """Enqueue deferred ARQ jobs for all date-based transitions on this event.

    Idempotent: each job carries the scheduled date as a token. If a date is later
    changed (e.g. funding deadline extended), the old job fires, detects a mismatch,
    and exits without making changes. The new job fires at the updated time.

    Note: event_date_deadline is NOT enqueued here — it doesn't exist at
    create/update time. It is enqueued by the transition_event_status job itself
    immediately after the approved→waiting_event_date transition calculates it.
    """
    from app.worker.redis_pool import enqueue as arq_enqueue

    if event.funding_end_at:
        await arq_enqueue(
            "transition_event_status",
            event.id,
            "funding_end_at",
            event.funding_end_at.isoformat(),
            _defer_until=event.funding_end_at,
        )
    if event.start_time:
        await arq_enqueue(
            "transition_event_status",
            event.id,
            "start_time",
            event.start_time.isoformat(),
            _defer_until=event.start_time,
        )
    if event.end_time:
        await arq_enqueue(
            "transition_event_status",
            event.id,
            "end_time",
            event.end_time.isoformat(),
            _defer_until=event.end_time,
        )


async def schedule_reserved_spots_release(
    event: "Event",
    db: "AsyncSession | None" = None,
) -> None:
    """Enqueue deferred job to zero reserved spots at the configured release time.

    release_at = selling_start + (start_time - selling_start) * pct / 100
    Effective pct = max(event.reserved_spots_release_percent or platform_min, platform_min).
    pct=100 (default) fires at start_time, identical to the old hardcoded behaviour.

    Pass ``db`` when an existing session is available (e.g. from a service/route);
    when omitted a short-lived session is opened internally (worker/standalone usage).
    """
    from app.worker.redis_pool import enqueue as arq_enqueue
    from app.services import platform_settings as settings_svc

    if event.start_time is None or event.ticket_selling_started_at is None:
        return

    if db is not None:
        platform_min = await settings_svc.get_int(db, "reserved_spots_release_percent_min")
    else:
        from app.db.base import async_session_maker
        async with async_session_maker() as _db:
            platform_min = await settings_svc.get_int(_db, "reserved_spots_release_percent_min")

    pct = event.reserved_spots_release_percent
    if pct is None:
        pct = platform_min
    else:
        pct = max(pct, platform_min)  # enforce floor at runtime too

    pct = max(0, min(100, pct))

    selling_start = event.ticket_selling_started_at
    selling_end = event.start_time
    # Ensure both are timezone-aware
    from datetime import timezone
    if selling_start.tzinfo is None:
        selling_start = selling_start.replace(tzinfo=timezone.utc)
    if selling_end.tzinfo is None:
        selling_end = selling_end.replace(tzinfo=timezone.utc)

    release_at = selling_start + (selling_end - selling_start) * (pct / 100)
    await arq_enqueue("release_reserved_spots", event.id, _defer_until=release_at)
