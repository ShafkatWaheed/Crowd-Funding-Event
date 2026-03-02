"""
Organizer-customer history: record_customer_attendance, list_organizer_customers, get_organizer_trust_score.
"""
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.event import OrganizerCustomerHistory
from app.repositories.event_repo import event_repo

logger = get_logger("svc.event.attendance")


async def record_customer_attendance(
    db: AsyncSession, *, organizer_id: int, customer_id: int, event_id: int, scanned_at: datetime,
) -> None:
    """Record that a customer attended an organizer's event. Idempotent (ignores duplicates)."""
    log_step(logger, "Record customer attendance", organizer_id=organizer_id, customer_id=customer_id, event_id=event_id)
    existing = await event_repo.get_attendance_record(db, organizer_id, customer_id, event_id)
    if existing:
        logger.debug("Attendance already recorded, skipping", extra={"organizer_id": organizer_id, "customer_id": customer_id, "event_id": event_id})
        return
    h = OrganizerCustomerHistory(
        organizer_id=organizer_id, customer_id=customer_id,
        event_id=event_id, scanned_at=scanned_at,
    )
    await event_repo.create_attendance_record(db, h)
    logger.info("Customer attendance recorded", extra={"organizer_id": organizer_id, "customer_id": customer_id, "event_id": event_id})


async def list_organizer_customers(
    db: AsyncSession, *, organizer_id: int, offset: int = 0, limit: int = 20,
) -> list[dict]:
    """List all unique customers who attended events organized by this organizer, with event count."""
    logger.debug("List organizer customers", extra={"organizer_id": organizer_id, "offset": offset, "limit": limit})
    rows = await event_repo.list_organizer_customers(db, organizer_id, offset=offset, limit=limit)
    return [
        {
            "customer_id": r.customer_id,
            "customer_name": r.display_name,
            "events_attended": r.events_attended,
            "last_attended": r.last_attended.isoformat() if r.last_attended else None,
        }
        for r in rows
    ]


async def get_organizer_trust_score(db: AsyncSession, *, organizer_id: int) -> dict:
    """
    Compute trust score for an organizer.

    Score = completed events / total published events (approved or beyond).
    Published means any event that has left the draft state at some point
    (approved, selling_tickets, waiting_event_date, live, completed, cancelled).

    Returns dict with score (0.0-1.0), completed count, published count,
    and a label (New / Low / Good / Excellent).
    """
    total_published = await event_repo.count_published_events(db, organizer_id)
    total_completed = await event_repo.count_completed_events(db, organizer_id)

    if total_published == 0:
        score = 0.0
        label = "New"
    else:
        score = round(total_completed / total_published, 2)
        if score >= 0.8:
            label = "Excellent"
        elif score >= 0.5:
            label = "Good"
        elif score >= 0.2:
            label = "Fair"
        else:
            label = "New" if total_completed == 0 else "Low"

    return {
        "organizer_id": organizer_id,
        "trust_score": score,
        "completed_events": int(total_completed),
        "published_events": int(total_published),
        "label": label,
    }
