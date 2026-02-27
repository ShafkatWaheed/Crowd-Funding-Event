"""
Event queries: get_my_registered_events, get_co_organized_events,
get_trending, get_coming_soon, get_popular, clone_event.
"""
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import select, func, and_, exists, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.logger import get_logger, log_step
from app.models.event import Event, EventOrganizer, EventStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User
from app.core.exceptions import ForbiddenError, ConflictError

from app.services.event.permissions import user_can_edit_event

logger = get_logger("svc.event.queries")


async def get_my_registered_events(
    db: AsyncSession, *, user_id: int, offset: int = 0, limit: int | None = None,
) -> Sequence[Event]:
    """Events the user is registered to (any registration status). Useful for 'My Events'."""
    logger.debug("get_my_registered_events", extra={"user_id": user_id, "offset": offset, "limit": limit})
    q = (
        select(Event)
        .join(Registration, Registration.event_id == Event.id)
        .where(
            Registration.user_id == user_id,
            Registration.status.in_([RegistrationStatus.registered, RegistrationStatus.waitlist]),
        )
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy), selectinload(Event.organizer))
        .order_by(Event.created_at.desc())
    )
    if offset:
        q = q.offset(offset)
    if limit is not None:
        q = q.limit(limit)
    result = await db.execute(q)
    return result.scalars().unique().all()


async def get_trending_events(db: AsyncSession, *, limit: int = 10, sponsorship_only: bool = False) -> Sequence[Event]:
    """Events ordered by registration_count DESC. Public-visible statuses."""
    logger.debug("get_trending_events", extra={"limit": limit, "sponsorship_only": sponsorship_only})
    from app.models.sponsor import SponsorshipCategory
    q = (
        select(Event)
        .where(Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live]))
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .order_by(Event.registration_count.desc(), Event.created_at.desc())
        .limit(limit)
    )
    if sponsorship_only:
        q = q.where(exists(
            select(SponsorshipCategory.id).where(
                SponsorshipCategory.event_id == Event.id,
                SponsorshipCategory.is_template == False,
            )
        ))
    result = await db.execute(q)
    return result.scalars().unique().all()


async def get_coming_soon_events(db: AsyncSession, *, limit: int = 10, sponsorship_only: bool = False) -> Sequence[Event]:
    """Approved events starting in the future, ordered by start_time ASC."""
    logger.debug("get_coming_soon_events", extra={"limit": limit, "sponsorship_only": sponsorship_only})
    from app.models.sponsor import SponsorshipCategory
    now = datetime.now(timezone.utc)
    q = (
        select(Event)
        .where(
            Event.status.in_([EventStatus.approved, EventStatus.selling_tickets]),
            Event.start_time.isnot(None),
            Event.start_time > now,
        )
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .order_by(Event.start_time.asc())
        .limit(limit)
    )
    if sponsorship_only:
        q = q.where(exists(
            select(SponsorshipCategory.id).where(
                SponsorshipCategory.event_id == Event.id,
                SponsorshipCategory.is_template == False,
            )
        ))
    result = await db.execute(q)
    return result.scalars().unique().all()


async def get_popular_events(db: AsyncSession, *, limit: int = 10, sponsorship_only: bool = False) -> Sequence[Event]:
    """Events with most pledged amount. Public-visible statuses."""
    logger.debug("get_popular_events", extra={"limit": limit, "sponsorship_only": sponsorship_only})
    from app.models.funding import Funding, FundingStatus
    from app.models.sponsor import SponsorshipCategory
    q = (
        select(Event, func.coalesce(func.sum(Funding.amount_cents), 0).label("total_pledged"))
        .outerjoin(Funding, and_(Funding.event_id == Event.id, Funding.status == FundingStatus.pledged))
        .where(Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live]))
        .group_by(Event.id)
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .order_by(func.coalesce(func.sum(Funding.amount_cents), 0).desc())
        .limit(limit)
    )
    if sponsorship_only:
        q = q.where(exists(
            select(SponsorshipCategory.id).where(
                SponsorshipCategory.event_id == Event.id,
                SponsorshipCategory.is_template == False,
            )
        ))
    result = await db.execute(q)
    return [row[0] for row in result.unique().all()]


async def clone_event(db: AsyncSession, event: Event, user: User) -> Event:
    """
    Clone a completed event into a new draft. Copies all params except
    start_time, end_time, funding_end_at (those must be set fresh).
    """
    log_step(logger, "Clone event", event_id=event.id, user_id=user.id)
    if event.status != EventStatus.completed:
        raise ConflictError("Only completed events can be cloned")
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot clone this event")
    new_event = Event(
        organizer_id=event.organizer_id,
        venue_id=event.venue_id,
        title=f"{event.title} (Copy)",
        description=event.description,
        start_time=None,
        end_time=None,
        lat=event.lat,
        lng=event.lng,
        funding_goal_cents=event.funding_goal_cents,
        funding_end_at=None,
        min_pledge_cents=event.min_pledge_cents,
        registration_type=event.registration_type,
        max_capacity=event.max_capacity,
        max_reserved_spots_per_user=event.max_reserved_spots_per_user,
        common_discount_percent=event.common_discount_percent,
        pledge_discount_percent=event.pledge_discount_percent,
        genre=event.genre,
        community_rules=event.community_rules,
        posts_enabled=event.posts_enabled,
        refund_deadline_days=None,
        ticket_strategy_id=event.ticket_strategy_id,
        status=EventStatus.draft,
    )
    db.add(new_event)
    await db.flush()
    await db.refresh(new_event)
    return new_event


async def get_co_organized_events(
    db: AsyncSession,
    *,
    user_id: int,
    status: str | None = None,
    search: str | None = None,
    offset: int = 0,
    limit: int = 20,
) -> Sequence[Event]:
    """Events where the user is an accepted co-organizer."""
    logger.debug("get_co_organized_events", extra={"user_id": user_id, "status": status, "search": search, "offset": offset, "limit": limit})
    q = (
        select(Event)
        .join(EventOrganizer, EventOrganizer.event_id == Event.id)
        .where(
            EventOrganizer.user_id == user_id,
            EventOrganizer.invitation_status == "accepted",
        )
        .options(
            selectinload(Event.venue),
            selectinload(Event.ticket_strategy),
            selectinload(Event.organizer),
        )
        .order_by(Event.created_at.desc())
    )
    if status is not None:
        try:
            status_enum = EventStatus(status)
        except ValueError:
            return []
        q = q.where(Event.status == status_enum)
    if search is not None and search.strip():
        q = q.where(Event.title.ilike(f"%{search.strip()}%"))
    if offset:
        q = q.offset(offset)
    q = q.limit(limit)
    result = await db.execute(q)
    return result.scalars().unique().all()


# ----- Event co-organizers (main organizer only can add/remove) -----
