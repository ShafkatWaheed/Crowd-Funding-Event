"""
Admin: list events for moderation, approve/reject, platform stats.
"""
from datetime import datetime, timezone

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventStatus
from app.models.funding import Funding
from app.models.ticket import TicketSale
from app.models.user import User
from app.services import event as event_service


async def list_users(db: AsyncSession) -> list[User]:
    """List all users (admin). Ordered by id."""
    result = await db.execute(select(User).order_by(User.id.asc()))
    return list(result.scalars().all())


async def list_events_for_admin(
    db: AsyncSession,
    *,
    status: str | None = None,
):
    """List events for admin view. Optional filter by status (e.g. pending_approval)."""
    return await event_service.list_events(
        db, status=status
    )


async def approve_or_reject_event(
    db: AsyncSession,
    event_id: int,
    approved: bool,
) -> Event:
    """
    Approve event (set status to approved) or reject (set back to draft).
    Returns the updated event. Raises NotFoundError if event not found.
    """
    event = await event_service.get_or_404(db, event_id)
    if approved:
        event.status = EventStatus.approved
    else:
        event.status = EventStatus.draft
    await db.flush()
    await db.refresh(event)
    return event


async def get_stats(db: AsyncSession) -> dict:
    """
    Return platform stats: events_total, events_pending, events_live, users_total,
    total_ticket_commission_cents, total_funding_commission_cents.
    """
    now = datetime.now(timezone.utc)
    total = (await db.execute(select(func.count()).select_from(Event))).scalar_one()
    pending = (
        await db.execute(
            select(func.count()).select_from(Event).where(Event.status == EventStatus.pending_approval)
        )
    ).scalar_one()
    live = (
        await db.execute(
            select(func.count()).select_from(Event).where(
                Event.status.in_([EventStatus.approved, EventStatus.live]),
                Event.start_time <= now,
                Event.end_time >= now,
            )
        )
    ).scalar_one()
    users_total = (await db.execute(select(func.count()).select_from(User))).scalar_one()

    # Commission totals
    ticket_commission = (
        await db.execute(
            select(func.coalesce(func.sum(TicketSale.commission_cents), 0))
        )
    ).scalar_one()
    funding_commission = (
        await db.execute(
            select(func.coalesce(func.sum(Funding.platform_cut_cents), 0))
        )
    ).scalar_one()

    return {
        "events_total": int(total),
        "events_pending": int(pending),
        "events_live": int(live),
        "users_total": int(users_total),
        "total_ticket_commission_cents": int(ticket_commission),
        "total_funding_commission_cents": int(funding_commission),
    }
