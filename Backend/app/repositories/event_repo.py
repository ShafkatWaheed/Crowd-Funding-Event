"""
Event data-access layer.

All SQLAlchemy queries for events, co-organizers, discounts, attendance,
lifecycle, and discovery live here.  Services must call these methods
instead of db.execute() directly.
"""
import math
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import (
    and_,
    delete as sa_delete,
    exists,
    func,
    nulls_last,
    or_,
    select,
    update as sa_update,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import (
    Event,
    EventDiscount,
    EventOrganizer,
    EventReaction,
    EventStatus,
    OrganizerCustomerHistory,
    RegistrationType,
)
from app.models.funding import Funding, FundingStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier, UserEventDiscount
from app.models.user import User
from app.models.venue import Venue
from app.repositories.base import BaseRepository


# ── Sort maps ────────────────────────────────────────────────────────

_MY_EVENTS_SORT = {
    "newest": Event.created_at.desc(),
    "oldest": Event.created_at.asc(),
    "name_az": Event.title.asc(),
    "soonest": Event.start_time.asc().nulls_last(),
}


class EventRepository(BaseRepository[Event]):
    model_class = Event

    # ═══════════════════════════════════════════════════════════════════
    #  Event CRUD
    # ═══════════════════════════════════════════════════════════════════

    async def get_by_id_with_relations(
        self,
        db: AsyncSession,
        event_id: int,
        *,
        load_venue: bool = False,
        load_organizer: bool = False,
    ) -> Event | None:
        """Load event by id with optional eager-loaded relations."""
        q = select(Event).where(Event.id == event_id)
        if load_venue:
            q = q.options(
                selectinload(Event.venue),
                selectinload(Event.ticket_strategy),
                selectinload(Event.organizer),
            )
        elif load_organizer:
            q = q.options(selectinload(Event.organizer))
        result = await db.execute(q)
        return result.scalar_one_or_none()

    async def create_event(self, db: AsyncSession, event: Event) -> Event:
        """Add a new event, flush, and refresh."""
        db.add(event)
        await db.flush()
        await db.refresh(event)
        return event

    async def flush_and_refresh(self, db: AsyncSession, event: Event) -> Event:
        """Flush pending changes and refresh the event from the database."""
        await db.flush()
        await db.refresh(event)
        return event

    async def flush_event(self, db: AsyncSession) -> None:
        """Flush pending changes without refresh."""
        await db.flush()

    async def delete_event(self, db: AsyncSession, event: Event) -> None:
        """Hard-delete an event row."""
        await db.delete(event)
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Event Listing & Search
    # ═══════════════════════════════════════════════════════════════════

    async def list_events(
        self,
        db: AsyncSession,
        *,
        search: str | None = None,
        city: str | None = None,
        status: str | None = None,
        live: bool | None = None,
        registration_type: str | None = None,
        organizer_id: int | None = None,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
        has_funding: bool | None = None,
        has_tickets: bool | None = None,
        min_capacity: int | None = None,
        max_capacity: int | None = None,
        genre: str | None = None,
        community_rules: bool | None = None,
        include_all_statuses: bool = False,
        sponsorship_only: bool = False,
        offset: int | None = None,
        limit: int | None = None,
        cursor_start_time: datetime | None = None,
        cursor_id: int | None = None,
    ) -> tuple[Sequence[Event], bool]:
        """
        List events with optional filters.

        When *cursor_start_time* and *cursor_id* are provided the query uses
        keyset pagination.  Returns ``(events, has_more)`` where *has_more*
        is True when there are rows beyond the requested *limit*.
        """
        conditions: list = []
        q = select(Event)
        need_venue_join = city is not None
        if search is not None and search.strip():
            need_venue_join = True
        if need_venue_join:
            q = q.outerjoin(Event.venue)
        if city is not None:
            conditions.append(Venue.city == city)
        if search is not None and search.strip():
            search_term = f"%{search.strip()}%"
            conditions.append(
                or_(
                    Event.title.ilike(search_term),
                    (Event.description.isnot(None)) & (Event.description.ilike(search_term)),
                    Venue.name.ilike(search_term),
                    Venue.city.ilike(search_term),
                    Venue.address.ilike(search_term),
                )
            )
        if status is not None:
            try:
                status_enum = EventStatus(status)
            except ValueError:
                return ([], False)
            conditions.append(Event.status == status_enum)
        elif not include_all_statuses and organizer_id is None:
            conditions.append(
                Event.status.notin_([
                    EventStatus.draft,
                    EventStatus.pending_approval,
                    EventStatus.cancelled,
                    EventStatus.completed,
                ])
            )
        if live is True:
            now = datetime.now(timezone.utc)
            conditions.append(Event.start_time.isnot(None))
            conditions.append(Event.start_time <= now)
            conditions.append(Event.end_time.isnot(None))
            conditions.append(Event.end_time >= now)
            conditions.append(
                Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live])
            )
        if registration_type is not None:
            try:
                reg_type = RegistrationType(registration_type)
            except ValueError:
                return ([], False)
            conditions.append(Event.registration_type == reg_type)
        if organizer_id is not None:
            conditions.append(Event.organizer_id == organizer_id)
        if date_from is not None:
            conditions.append(Event.start_time.isnot(None))
            conditions.append(Event.start_time >= date_from)
        if date_to is not None:
            conditions.append(Event.start_time.isnot(None))
            conditions.append(Event.start_time <= date_to)
        if has_funding is True:
            conditions.append(
                or_(Event.funding_goal_cents.isnot(None), Event.funding_end_at.isnot(None))
            )
        if has_funding is False:
            conditions.append(Event.funding_goal_cents.is_(None))
            conditions.append(Event.funding_end_at.is_(None))
        if has_tickets is True:
            conditions.append(exists(select(1).where(TicketTier.event_id == Event.id)))
        if has_tickets is False:
            conditions.append(~exists(select(1).where(TicketTier.event_id == Event.id)))
        if min_capacity is not None:
            conditions.append(Event.max_capacity >= min_capacity)
        if max_capacity is not None:
            conditions.append(Event.max_capacity <= max_capacity)
        if genre is not None:
            conditions.append(Event.genre == genre)
        if community_rules is not None:
            conditions.append(Event.community_rules == community_rules)
        if sponsorship_only:
            from app.models.sponsor import SponsorshipCategory

            conditions.append(
                exists(
                    select(SponsorshipCategory.id).where(
                        SponsorshipCategory.event_id == Event.id,
                        SponsorshipCategory.is_template == False,  # noqa: E712
                    )
                )
            )
        if conditions:
            q = q.where(and_(*conditions))

        # Keyset pagination
        use_keyset = cursor_id is not None and limit is not None
        if use_keyset:
            if cursor_start_time is not None:
                keyset = or_(
                    Event.start_time > cursor_start_time,
                    (Event.start_time == cursor_start_time) & (Event.id > cursor_id),
                    Event.start_time.is_(None),
                )
            else:
                keyset = or_(
                    Event.start_time.isnot(None),
                    (Event.start_time.is_(None) & (Event.id > cursor_id)),
                )
            q = q.where(keyset)

        q = q.options(
            selectinload(Event.venue),
            selectinload(Event.ticket_strategy),
            selectinload(Event.organizer),
        ).order_by(nulls_last(Event.start_time.asc()), Event.id.asc())

        if not use_keyset and offset is not None and offset > 0:
            q = q.offset(offset)
        if limit is not None:
            q = q.limit(limit + 1 if use_keyset else limit)
        result = await db.execute(q)
        rows = list(result.scalars().unique().all())

        has_more = False
        if use_keyset and limit is not None and len(rows) > limit:
            rows = rows[:limit]
            has_more = True

        return (rows, has_more)

    async def list_events_for_map(
        self,
        db: AsyncSession,
        *,
        city: str | None = None,
        live: bool | None = None,
        lat: float | None = None,
        lng: float | None = None,
        radius_km: float | None = None,
        organizer_id: int | None = None,
        search: str | None = None,
        genre: str | None = None,
        status: str | None = None,
        sponsorship_only: bool = False,
    ) -> Sequence[Event]:
        """List events with lat/lng for map markers."""
        conditions = [
            Event.lat.isnot(None),
            Event.lng.isnot(None),
        ]
        if organizer_id is not None:
            conditions.append(Event.organizer_id == organizer_id)
        if status is not None:
            try:
                status_enum = EventStatus(status)
            except ValueError:
                return []
            conditions.append(Event.status == status_enum)
        elif organizer_id is None:
            conditions.append(
                Event.status.notin_([
                    EventStatus.draft,
                    EventStatus.pending_approval,
                    EventStatus.cancelled,
                    EventStatus.completed,
                ]),
            )
        need_venue_join = city is not None
        if search is not None and search.strip():
            search_term = f"%{search.strip()}%"
            need_venue_join = True
            conditions.append(
                or_(
                    Event.title.ilike(search_term),
                    Venue.name.ilike(search_term),
                    Venue.city.ilike(search_term),
                    Venue.address.ilike(search_term),
                )
            )
        if genre is not None:
            conditions.append(Event.genre == genre)
        if sponsorship_only:
            from app.models.sponsor import SponsorshipCategory

            conditions.append(
                exists(
                    select(SponsorshipCategory.id).where(
                        SponsorshipCategory.event_id == Event.id,
                        SponsorshipCategory.is_template == False,  # noqa: E712
                    )
                )
            )
        q = select(Event)
        if need_venue_join:
            q = q.outerjoin(Event.venue)
        if city is not None:
            conditions.append(Venue.city == city)
        if live is True:
            now = datetime.now(timezone.utc)
            conditions.append(Event.start_time.isnot(None))
            conditions.append(Event.start_time <= now)
            conditions.append(Event.end_time.isnot(None))
            conditions.append(Event.end_time >= now)
            conditions.append(
                Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live])
            )
        if lat is not None and lng is not None and radius_km is not None and radius_km > 0:
            delta_lat = radius_km / 111.0
            delta_lng = radius_km / (111.0 * math.cos(math.radians(lat)) if lat != 0 else 111.0)
            conditions.append(Event.lat >= lat - delta_lat)
            conditions.append(Event.lat <= lat + delta_lat)
            conditions.append(Event.lng >= lng - delta_lng)
            conditions.append(Event.lng <= lng + delta_lng)
        q = (
            q.options(selectinload(Event.venue))
            .where(and_(*conditions))
            .order_by(Event.start_time.asc())
        )
        result = await db.execute(q)
        return result.scalars().unique().all()

    async def count_active_events(self, db: AsyncSession, organizer_id: int) -> int:
        """Count non-cancelled/non-completed events for an organizer."""
        q = select(func.count()).select_from(Event).where(
            Event.organizer_id == organizer_id,
            Event.status.notin_(["cancelled", "completed"]),
        )
        return int((await db.execute(q)).scalar_one())

    # ═══════════════════════════════════════════════════════════════════
    #  Event Discovery
    # ═══════════════════════════════════════════════════════════════════

    async def list_registered_events(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        offset: int = 0,
        limit: int | None = None,
        sort_by: str = "newest",
    ) -> Sequence[Event]:
        """Events the user is registered for (registered or waitlisted)."""
        q = (
            select(Event)
            .join(Registration, Registration.event_id == Event.id)
            .where(
                Registration.user_id == user_id,
                Registration.status.in_([RegistrationStatus.registered, RegistrationStatus.waitlist]),
            )
            .options(
                selectinload(Event.venue),
                selectinload(Event.ticket_strategy),
                selectinload(Event.organizer),
            )
            .order_by(_MY_EVENTS_SORT.get(sort_by, Event.created_at.desc()))
        )
        if offset:
            q = q.offset(offset)
        if limit is not None:
            q = q.limit(limit)
        result = await db.execute(q)
        return result.scalars().unique().all()

    async def list_co_organized_events(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        status: str | None = None,
        search: str | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> Sequence[Event]:
        """Events where the user is an accepted co-organizer."""
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

    async def list_trending_events(
        self,
        db: AsyncSession,
        *,
        limit: int = 10,
        sponsorship_only: bool = False,
    ) -> Sequence[Event]:
        """Events ordered by registration_count DESC (public-visible statuses)."""
        q = (
            select(Event)
            .where(Event.status.in_([EventStatus.approved, EventStatus.selling_tickets, EventStatus.live]))
            .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
            .order_by(Event.registration_count.desc(), Event.created_at.desc())
            .limit(limit)
        )
        if sponsorship_only:
            from app.models.sponsor import SponsorshipCategory

            q = q.where(
                exists(
                    select(SponsorshipCategory.id).where(
                        SponsorshipCategory.event_id == Event.id,
                        SponsorshipCategory.is_template == False,  # noqa: E712
                    )
                )
            )
        result = await db.execute(q)
        return result.scalars().unique().all()

    async def list_coming_soon_events(
        self,
        db: AsyncSession,
        *,
        limit: int = 10,
        sponsorship_only: bool = False,
    ) -> Sequence[Event]:
        """Approved events starting in the future, ordered by start_time ASC."""
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
            from app.models.sponsor import SponsorshipCategory

            q = q.where(
                exists(
                    select(SponsorshipCategory.id).where(
                        SponsorshipCategory.event_id == Event.id,
                        SponsorshipCategory.is_template == False,  # noqa: E712
                    )
                )
            )
        result = await db.execute(q)
        return result.scalars().unique().all()

    async def list_popular_events(
        self,
        db: AsyncSession,
        *,
        limit: int = 10,
        sponsorship_only: bool = False,
    ) -> list[Event]:
        """Events with most pledged amount (public-visible statuses)."""
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
            from app.models.sponsor import SponsorshipCategory

            q = q.where(
                exists(
                    select(SponsorshipCategory.id).where(
                        SponsorshipCategory.event_id == Event.id,
                        SponsorshipCategory.is_template == False,  # noqa: E712
                    )
                )
            )
        result = await db.execute(q)
        return [row[0] for row in result.unique().all()]

    # ═══════════════════════════════════════════════════════════════════
    #  Event Lifecycle
    # ═══════════════════════════════════════════════════════════════════

    async def has_ticket_tiers(self, db: AsyncSession, event_id: int) -> bool:
        """Return True if the event has at least one ticket tier."""
        result = await db.execute(
            select(TicketTier.id).where(TicketTier.event_id == event_id).limit(1)
        )
        return result.scalar_one_or_none() is not None

    async def count_ticket_tiers(self, db: AsyncSession, event_id: int) -> int:
        """Count ticket tiers for an event."""
        q = select(func.count()).where(TicketTier.event_id == event_id)
        return int((await db.execute(q)).scalar_one())

    async def zero_reserved_spots(self, db: AsyncSession, event_id: int) -> None:
        """Set reserved_spots to 0 for all pledged fundings of an event."""
        await db.execute(
            sa_update(Funding)
            .where(
                Funding.event_id == event_id,
                Funding.status == FundingStatus.pledged,
                Funding.reserved_spots > 0,
            )
            .values(reserved_spots=0)
        )

    async def get_escrow_records(
        self,
        db: AsyncSession,
        event_id: int,
    ) -> tuple:
        """
        Return (fund_escrow, ticket_escrow, sponsor_escrow) for the event.
        Each is the model instance or None.
        """
        from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow

        fund = (await db.execute(
            select(FundEscrow).where(FundEscrow.event_id == event_id)
        )).scalar_one_or_none()
        ticket = (await db.execute(
            select(TicketEscrow).where(TicketEscrow.event_id == event_id)
        )).scalar_one_or_none()
        sponsor = (await db.execute(
            select(SponsorEscrow).where(SponsorEscrow.event_id == event_id)
        )).scalar_one_or_none()
        return fund, ticket, sponsor

    async def purge_event_children(self, db: AsyncSession, event_id: int) -> None:
        """Delete all child records for an event before hard-deleting the event itself."""
        from app.models.escrow import EscrowRelease, FundEscrow
        from app.models.discount_strategy import CustomerDiscountClaim, EventDiscountStrategyLink
        from app.models.post import EventPost
        from app.models.image import EventImage

        # Escrow releases (child of escrow)
        escrow_ids_q = select(FundEscrow.id).where(FundEscrow.event_id == event_id)
        await db.execute(sa_delete(EscrowRelease).where(EscrowRelease.escrow_id.in_(escrow_ids_q)))
        await db.execute(sa_delete(FundEscrow).where(FundEscrow.event_id == event_id))

        # Discount claims (child of strategy links)
        link_ids_q = select(EventDiscountStrategyLink.id).where(
            EventDiscountStrategyLink.event_id == event_id
        )
        await db.execute(sa_delete(CustomerDiscountClaim).where(CustomerDiscountClaim.link_id.in_(link_ids_q)))
        await db.execute(sa_delete(EventDiscountStrategyLink).where(EventDiscountStrategyLink.event_id == event_id))

        # Ticket sales (child of both event and ticket_tier)
        await db.execute(sa_delete(TicketSale).where(TicketSale.event_id == event_id))
        await db.execute(sa_delete(TicketTier).where(TicketTier.event_id == event_id))
        await db.execute(sa_delete(UserEventDiscount).where(UserEventDiscount.event_id == event_id))

        # Fundings, registrations
        await db.execute(sa_delete(Funding).where(Funding.event_id == event_id))
        await db.execute(sa_delete(Registration).where(Registration.event_id == event_id))

        # Other children
        await db.execute(sa_delete(EventOrganizer).where(EventOrganizer.event_id == event_id))
        await db.execute(sa_delete(EventReaction).where(EventReaction.event_id == event_id))
        await db.execute(sa_delete(EventDiscount).where(EventDiscount.event_id == event_id))
        await db.execute(sa_delete(EventPost).where(EventPost.event_id == event_id))
        await db.execute(sa_delete(EventImage).where(EventImage.event_id == event_id))

        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Co-Organizers
    # ═══════════════════════════════════════════════════════════════════

    async def list_event_organizers(
        self, db: AsyncSession, event_id: int
    ) -> list[EventOrganizer]:
        """Return co-organizers for the event, with user relation eager-loaded."""
        q = (
            select(EventOrganizer)
            .where(EventOrganizer.event_id == event_id)
            .options(selectinload(EventOrganizer.user))
            .order_by(EventOrganizer.created_at.asc())
        )
        result = await db.execute(q)
        return list(result.scalars().unique().all())

    async def get_co_organizer(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> EventOrganizer | None:
        """Get a co-organizer record by event_id + user_id."""
        q = select(EventOrganizer).where(
            EventOrganizer.event_id == event_id,
            EventOrganizer.user_id == user_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def get_co_organizer_by_id(
        self, db: AsyncSession, co_org_id: int
    ) -> EventOrganizer | None:
        """Get a co-organizer record by its primary key."""
        q = select(EventOrganizer).where(EventOrganizer.id == co_org_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def count_co_organizers(
        self, db: AsyncSession, event_id: int, *, exclude_declined: bool = True
    ) -> int:
        """Count co-organizers for an event (excluding declined by default)."""
        conditions = [EventOrganizer.event_id == event_id]
        if exclude_declined:
            conditions.append(EventOrganizer.invitation_status != "declined")
        q = select(func.count()).where(*conditions)
        return int((await db.execute(q)).scalar_one())

    async def create_co_organizer(
        self, db: AsyncSession, co_org: EventOrganizer
    ) -> EventOrganizer:
        """Add a new co-organizer row, flush, and refresh."""
        db.add(co_org)
        await db.flush()
        await db.refresh(co_org)
        return co_org

    async def flush_and_refresh_co_organizer(
        self, db: AsyncSession, co_org: EventOrganizer
    ) -> EventOrganizer:
        """Flush pending changes and refresh a co-organizer from the database."""
        await db.flush()
        await db.refresh(co_org)
        return co_org

    async def delete_co_organizer(
        self, db: AsyncSession, co_org: EventOrganizer
    ) -> None:
        """Delete a co-organizer record."""
        await db.delete(co_org)
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Permissions
    # ═══════════════════════════════════════════════════════════════════

    async def get_accepted_co_organizer(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> EventOrganizer | None:
        """
        Return the accepted co-organizer record for (event, user) or None.
        Used by permission checks.
        """
        q = select(EventOrganizer).where(
            EventOrganizer.event_id == event_id,
            EventOrganizer.user_id == user_id,
            EventOrganizer.invitation_status == "accepted",
        )
        return (await db.execute(q)).scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════════
    #  Event Discounts
    # ═══════════════════════════════════════════════════════════════════

    async def list_event_discounts(
        self, db: AsyncSession, event_id: int
    ) -> list[EventDiscount]:
        """Return all discounts for an event ordered by id."""
        q = select(EventDiscount).where(EventDiscount.event_id == event_id).order_by(EventDiscount.id)
        return list((await db.execute(q)).scalars().all())

    async def get_event_discount(
        self, db: AsyncSession, event_id: int, discount_id: int
    ) -> EventDiscount | None:
        """Get a single event discount by id + event_id."""
        q = select(EventDiscount).where(
            EventDiscount.id == discount_id,
            EventDiscount.event_id == event_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def create_event_discount(
        self, db: AsyncSession, discount: EventDiscount
    ) -> EventDiscount:
        """Add a new event discount, flush, and refresh."""
        db.add(discount)
        await db.flush()
        await db.refresh(discount)
        return discount

    async def delete_event_discount(
        self, db: AsyncSession, discount: EventDiscount
    ) -> None:
        """Delete an event discount row."""
        await db.delete(discount)
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Attendance & Trust
    # ═══════════════════════════════════════════════════════════════════

    async def get_attendance_record(
        self,
        db: AsyncSession,
        organizer_id: int,
        customer_id: int,
        event_id: int,
    ) -> OrganizerCustomerHistory | None:
        """Check if a customer attendance record already exists."""
        q = select(OrganizerCustomerHistory).where(
            OrganizerCustomerHistory.organizer_id == organizer_id,
            OrganizerCustomerHistory.customer_id == customer_id,
            OrganizerCustomerHistory.event_id == event_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def create_attendance_record(
        self, db: AsyncSession, record: OrganizerCustomerHistory
    ) -> None:
        """Insert a new customer attendance record."""
        db.add(record)
        await db.flush()

    async def list_organizer_customers(
        self,
        db: AsyncSession,
        organizer_id: int,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> list:
        """
        List unique customers who attended events organized by this organizer,
        with event count and last-attended timestamp.  Returns raw row tuples.
        """
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
        return list((await db.execute(q)).all())

    async def count_published_events(self, db: AsyncSession, organizer_id: int) -> int:
        """Count events that have left draft (published statuses)."""
        published_statuses = [
            EventStatus.approved,
            EventStatus.pending_approval,
            EventStatus.selling_tickets,
            EventStatus.waiting_event_date,
            EventStatus.live,
            EventStatus.completed,
            EventStatus.cancelled,
        ]
        q = select(func.count()).where(
            Event.organizer_id == organizer_id,
            Event.status.in_(published_statuses),
        )
        return int((await db.execute(q)).scalar_one())

    async def count_completed_events(self, db: AsyncSession, organizer_id: int) -> int:
        """Count completed events for an organizer."""
        q = select(func.count()).where(
            Event.organizer_id == organizer_id,
            Event.status == EventStatus.completed,
        )
        return int((await db.execute(q)).scalar_one())

    # ═══════════════════════════════════════════════════════════════════
    #  Venue Queries
    # ═══════════════════════════════════════════════════════════════════

    async def get_venue(self, db: AsyncSession, venue_id: int) -> Venue | None:
        """Look up a venue by id."""
        q = select(Venue).where(Venue.id == venue_id)
        return (await db.execute(q)).scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════════
    #  Ticket Strategy Queries
    # ═══════════════════════════════════════════════════════════════════

    async def get_ticket_strategy(self, db: AsyncSession, strategy_id: int):
        """Look up a ticket strategy by id. Returns model instance or None."""
        from app.models.ticket_strategy import TicketStrategy

        q = select(TicketStrategy).where(TicketStrategy.id == strategy_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def get_strategy_tiers(self, db: AsyncSession, strategy_id: int) -> list:
        """Return all tiers for a ticket strategy."""
        from app.models.ticket_strategy import TicketStrategyTier

        q = select(TicketStrategyTier).where(TicketStrategyTier.strategy_id == strategy_id)
        return list((await db.execute(q)).scalars().all())

    # ═══════════════════════════════════════════════════════════════════
    #  Ticket Tier helpers (used by event create/update/lifecycle)
    # ═══════════════════════════════════════════════════════════════════

    async def get_existing_tiers(
        self, db: AsyncSession, event_id: int
    ) -> list[TicketTier]:
        """Return all ticket tiers for an event."""
        q = select(TicketTier).where(TicketTier.event_id == event_id)
        return list((await db.execute(q)).scalars().all())

    async def has_ticket_sales(self, db: AsyncSession, event_id: int) -> bool:
        """Return True if the event has any ticket sales."""
        result = await db.execute(
            select(TicketSale).where(TicketSale.event_id == event_id).limit(1)
        )
        return result.scalar_one_or_none() is not None

    async def count_tickets_sold(self, db: AsyncSession, event_id: int) -> int:
        """Count purchased tickets for an event."""
        q = select(func.count()).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
        )
        return int((await db.execute(q)).scalar_one())

    async def delete_tier(self, db: AsyncSession, tier: TicketTier) -> None:
        """Delete a single ticket tier."""
        await db.delete(tier)

    async def count_tier_tiers(self, db: AsyncSession, event_id: int) -> int:
        """Alias for count_ticket_tiers (backward compat)."""
        return await self.count_ticket_tiers(db, event_id)

    # ═══════════════════════════════════════════════════════════════════
    #  User lookup (used by co-organizer flows)
    # ═══════════════════════════════════════════════════════════════════

    async def get_user_by_id(self, db: AsyncSession, user_id: int) -> User | None:
        """Look up a user by id."""
        q = select(User).where(User.id == user_id)
        return (await db.execute(q)).scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════════
    #  Clone
    # ═══════════════════════════════════════════════════════════════════

    async def clone_event(self, db: AsyncSession, event: Event) -> Event:
        """
        Create a copy of the event as a new draft.
        Copies all params except start_time, end_time, funding_end_at.
        """
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

    # ═══════════════════════════════════════════════════════════════════
    #  Publish helpers
    # ═══════════════════════════════════════════════════════════════════

    async def count_tier_for_event(self, db: AsyncSession, event_id: int) -> int:
        """Count ticket tiers (used by publish validation)."""
        q = select(func.count()).select_from(TicketTier).where(TicketTier.event_id == event_id)
        return int((await db.execute(q)).scalar_one())

    # ═══════════════════════════════════════════════════════════════════
    #  Discount queries (used by compute_event_discounts_for_user)
    # ═══════════════════════════════════════════════════════════════════

    async def get_discount_strategy_links(
        self, db: AsyncSession, event_id: int
    ) -> list:
        """Return all discount strategy links for an event with strategy eager-loaded."""
        from app.models.discount_strategy import EventDiscountStrategyLink

        q = (
            select(EventDiscountStrategyLink)
            .options(selectinload(EventDiscountStrategyLink.strategy))
            .where(EventDiscountStrategyLink.event_id == event_id)
        )
        return list((await db.execute(q)).scalars().all())

    async def get_claimed_link_ids(
        self, db: AsyncSession, user_id: int, link_ids: list[int]
    ) -> set[int]:
        """Return link IDs that the user has already claimed."""
        from app.models.discount_strategy import CustomerDiscountClaim

        if not link_ids:
            return set()
        q = select(CustomerDiscountClaim.link_id).where(
            CustomerDiscountClaim.user_id == user_id,
            CustomerDiscountClaim.link_id.in_(link_ids),
        )
        return set((await db.execute(q)).scalars().all())

    async def get_user_pledged_total(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> int:
        """Sum of pledged amounts for a specific user on a specific event."""
        q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(q)).scalar_one())


# Module-level singleton
event_repo = EventRepository()
