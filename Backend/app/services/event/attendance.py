"""
Organizer–customer history: record_customer_attendance, list_organizer_customers, get_organizer_trust_score.
"""
from datetime import datetime

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.event import Event, EventStatus, OrganizerCustomerHistory
from app.models.user import User

logger = get_logger("svc.event.attendance")


async def record_customer_attendance(
    db: AsyncSession, *, organizer_id: int, customer_id: int, event_id: int, scanned_at: datetime,
) -> None:
    """Record that a customer attended an organizer's event. Idempotent (ignores duplicates)."""
    log_step(logger, "Record customer attendance", organizer_id=organizer_id, customer_id=customer_id, event_id=event_id)
    existing = (
        await db.execute(
            select(OrganizerCustomerHistory).where(
                OrganizerCustomerHistory.organizer_id == organizer_id,
                OrganizerCustomerHistory.customer_id == customer_id,
                OrganizerCustomerHistory.event_id == event_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        logger.debug("Attendance already recorded, skipping", extra={"organizer_id": organizer_id, "customer_id": customer_id, "event_id": event_id})
        return
    h = OrganizerCustomerHistory(
        organizer_id=organizer_id, customer_id=customer_id,
        event_id=event_id, scanned_at=scanned_at,
    )
    db.add(h)
    await db.flush()
    logger.info("Customer attendance recorded", extra={"organizer_id": organizer_id, "customer_id": customer_id, "event_id": event_id})


async def list_organizer_customers(
    db: AsyncSession, *, organizer_id: int, offset: int = 0, limit: int = 20,
) -> list[dict]:
    """List all unique customers who attended events organized by this organizer, with event count."""
    logger.debug("List organizer customers", extra={"organizer_id": organizer_id, "offset": offset, "limit": limit})
    q = (
        select(
            OrganizerCustomerHistory.customer_id,
            User.display_name,
            func.count(OrganizerCustomerHistory.id).label("events_attended"),
            func.max(OrganizerCustomerHistory.scanned_at).label("last_attended"),
        )
        .join(User, User.id == OrganizerCustomerHistory.customer_id)
        .where(OrganizerCustomerHistory.organizer_id == organizer_id)
        .group_by(OrganizerCustomerHistory.customer_id, User.display_name)
        .order_by(func.count(OrganizerCustomerHistory.id).desc())
        .offset(offset)
        .limit(limit)
    )
    rows = (await db.execute(q)).all()
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

    Returns dict with score (0.0–1.0), completed count, published count,
    and a label (New / Low / Good / Excellent).
    """
    published_statuses = [
        EventStatus.approved,
        EventStatus.pending_approval,
        EventStatus.selling_tickets,
        EventStatus.waiting_event_date,
        EventStatus.live,
        EventStatus.completed,
        EventStatus.cancelled,
    ]

    total_published = (await db.execute(
        select(func.count()).where(
            Event.organizer_id == organizer_id,
            Event.status.in_(published_statuses),
        )
    )).scalar_one()

    total_completed = (await db.execute(
        select(func.count()).where(
            Event.organizer_id == organizer_id,
            Event.status == EventStatus.completed,
        )
    )).scalar_one()

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
