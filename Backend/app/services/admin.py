"""
Admin: list events for moderation, approve/reject, platform stats, validation warnings.
"""
from datetime import datetime, timezone

from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventStatus
from app.models.funding import Funding
from app.models.ticket import TicketSale
from app.models.user import User
from app.services import event as event_service


async def list_users(
    db: AsyncSession,
    *,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
) -> tuple[list[User], int]:
    """List users (admin) with pagination + search. Returns (items, total)."""
    base = select(User)
    if search:
        pattern = f"%{search}%"
        base = base.where(or_(User.display_name.ilike(pattern), User.email.ilike(pattern)))
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one()
    q = base.order_by(User.id.asc()).offset(offset).limit(limit)
    items = list((await db.execute(q)).scalars().all())
    return items, int(total)


async def list_events_for_admin(
    db: AsyncSession,
    *,
    status: str | None = None,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
) -> tuple[list[Event], int]:
    """List events for admin view with pagination + search. Returns (items, total)."""
    base = select(Event)
    if status:
        try:
            base = base.where(Event.status == EventStatus(status))
        except ValueError:
            pass
    if search:
        pattern = f"%{search}%"
        base = base.where(Event.title.ilike(pattern))
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one()
    q = base.order_by(Event.created_at.desc()).offset(offset).limit(limit)
    items = list((await db.execute(q)).scalars().all())
    return items, int(total)


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


def compute_event_warnings(event: Event) -> list[str]:
    """Inspect an Event and return a list of human-readable warning strings."""
    now = datetime.now(timezone.utc)
    warnings: list[str] = []

    if not event.description or len(event.description.strip()) < 20:
        warnings.append("Description is missing or too short")
    if not event.funding_goal_cents and event.funding_end_at:
        warnings.append("Funding deadline set but goal is $0")
    if event.funding_goal_cents and not event.funding_end_at:
        warnings.append("Funding goal set but no funding deadline")
    if event.max_capacity == 0:
        warnings.append("Capacity is 0")
    if (
        not event.ticket_strategy_id
        and event.status in (EventStatus.selling_tickets, EventStatus.approved)
        and not event.funding_end_at
    ):
        warnings.append("No ticket tier assigned")

    def _tz(dt: datetime | None) -> datetime | None:
        if dt is None:
            return None
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)

    if event.start_time and _tz(event.start_time) < now:
        if event.status in (EventStatus.draft, EventStatus.pending_approval, EventStatus.under_review):
            warnings.append("Event start date is in the past")
    if event.end_time and event.start_time and _tz(event.end_time) <= _tz(event.start_time):
        warnings.append("End time is before or equal to start time")
    if event.funding_end_at and _tz(event.funding_end_at) < now:
        if event.status in (EventStatus.draft, EventStatus.pending_approval):
            warnings.append("Funding deadline already passed")
    if not event.genre:
        warnings.append("No genre/category set")

    return warnings


async def get_stats(db: AsyncSession) -> dict:
    """
    Return platform stats: events_total, events_pending, events_live, users_total,
    total_ticket_commission_cents, total_funding_commission_cents, total_escrow_held_cents.
    """
    from app.models.escrow import FundEscrow

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

    try:
        escrow_held = (
            await db.execute(
                select(func.coalesce(func.sum(FundEscrow.total_held_cents), 0))
            )
        ).scalar_one()
    except Exception:
        escrow_held = 0

    return {
        "events_total": int(total),
        "events_pending": int(pending),
        "events_live": int(live),
        "users_total": int(users_total),
        "total_ticket_commission_cents": int(ticket_commission),
        "total_funding_commission_cents": int(funding_commission),
        "total_escrow_held_cents": int(escrow_held),
    }
