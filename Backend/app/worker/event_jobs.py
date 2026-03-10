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
