"""
Organizer dashboard data-access layer.

All SQLAlchemy aggregation queries for the organizer dashboard live here.
Services must call these methods instead of db.execute() directly.
"""
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import and_, case, cast, func, literal, select, String, union_all
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.sponsor import BidStatus, SponsorBid, SponsorshipCategory, SponsorPayment
from app.models.user import User


class DashboardRepository:
    """Pure data-access for organizer dashboard aggregation queries."""

    # ===================================================================
    #  Query builders
    # ===================================================================

    @staticmethod
    def build_org_event_ids_query(
        organizer_id: int,
        *,
        event_id: int | None = None,
        status_filter: str | None = None,
        genre: str | None = None,
    ):
        """Build the base org_event_ids subquery (returns a Select)."""
        q = select(Event.id).where(Event.organizer_id == organizer_id)
        if event_id is not None:
            q = q.where(Event.id == event_id)
        elif status_filter:
            try:
                status_enum = EventStatus(status_filter)
                q = q.where(Event.status == status_enum)
            except ValueError:
                pass
        if genre:
            q = q.where(Event.genre == genre)
        return q

    @staticmethod
    def build_org_events_excl_draft(org_event_ids_q):
        """Return org_event_ids_q with draft excluded."""
        return org_event_ids_q.where(Event.status != EventStatus.draft)

    # ===================================================================
    #  Organizer KPIs (consolidated aggregation)
    # ===================================================================

    async def get_ticket_kpis(
        self, db: AsyncSession, org_event_ids_q, period_start: datetime, prev_start: datetime
    ):
        """Return consolidated ticket KPI row for the organizer."""
        t_ref_statuses = [
            TicketSaleStatus.refunded,
            TicketSaleStatus.refund_requested,
            TicketSaleStatus.refund_processing,
        ]
        t_cur = TicketSale.created_at >= period_start
        t_prev = and_(TicketSale.created_at >= prev_start, TicketSale.created_at < period_start)
        t_active = TicketSale.status != TicketSaleStatus.cancelled
        t_refunded = TicketSale.status.in_(t_ref_statuses)

        return (await db.execute(
            select(
                func.coalesce(func.sum(case((and_(t_active, t_cur), TicketSale.net_to_organizer_cents))), 0).label("cur_rev"),
                func.coalesce(func.sum(case((and_(t_active, t_prev), TicketSale.net_to_organizer_cents))), 0).label("prev_rev"),
                func.coalesce(func.sum(case((t_active, TicketSale.net_to_organizer_cents))), 0).label("all_rev"),
                func.count(case((and_(t_active, t_cur), 1))).label("cur_sold"),
                func.count(case((and_(t_active, t_prev), 1))).label("prev_sold"),
                func.count(case((t_active, 1))).label("all_sold"),
                func.count().label("all_total"),
                func.count(case((t_refunded, 1))).label("all_refunded"),
                func.count(case((t_cur, 1))).label("cur_total"),
                func.count(case((and_(t_refunded, t_cur), 1))).label("cur_refunded"),
                func.count(case((t_prev, 1))).label("prev_total"),
                func.count(case((and_(t_refunded, t_prev), 1))).label("prev_refunded"),
            )
            .select_from(TicketSale)
            .where(TicketSale.event_id.in_(org_event_ids_q))
        )).one()

    async def get_funding_kpis(
        self, db: AsyncSession, org_event_ids_q, period_start: datetime, prev_start: datetime
    ):
        """Return consolidated funding KPI row for the organizer."""
        f_pledged = Funding.status == FundingStatus.pledged
        f_cur = Funding.created_at >= period_start
        f_prev = and_(Funding.created_at >= prev_start, Funding.created_at < period_start)
        f_ref_statuses = [FundingStatus.refunded, FundingStatus.refund_processing]
        f_refunded = Funding.status.in_(f_ref_statuses)

        return (await db.execute(
            select(
                func.coalesce(func.sum(case((and_(f_pledged, f_cur), Funding.net_to_organizer_cents))), 0).label("cur_rev"),
                func.coalesce(func.sum(case((and_(f_pledged, f_prev), Funding.net_to_organizer_cents))), 0).label("prev_rev"),
                func.coalesce(func.sum(case((f_pledged, Funding.net_to_organizer_cents))), 0).label("all_rev"),
                func.count(case((and_(f_pledged, f_cur), 1))).label("cur_backers"),
                func.count(case((and_(f_pledged, f_prev), 1))).label("prev_backers"),
                func.count(case((f_pledged, 1))).label("all_backers"),
                func.count().label("all_total"),
                func.count(case((f_refunded, 1))).label("all_refunded"),
                func.count(case((f_cur, 1))).label("cur_total"),
                func.count(case((and_(f_refunded, f_cur), 1))).label("cur_refunded"),
                func.count(case((f_prev, 1))).label("prev_total"),
                func.count(case((and_(f_refunded, f_prev), 1))).label("prev_refunded"),
            )
            .select_from(Funding)
            .where(Funding.event_id.in_(org_event_ids_q))
        )).one()

    async def get_sponsor_payment_kpis(
        self, db: AsyncSession, org_event_ids_q, period_start: datetime, prev_start: datetime
    ):
        """Return consolidated sponsor-payment revenue row."""
        sp_cur = SponsorPayment.created_at >= period_start
        sp_prev = and_(SponsorPayment.created_at >= prev_start, SponsorPayment.created_at < period_start)

        return (await db.execute(
            select(
                func.coalesce(func.sum(case((sp_cur, SponsorPayment.net_to_organizer_cents))), 0).label("cur_rev"),
                func.coalesce(func.sum(case((sp_prev, SponsorPayment.net_to_organizer_cents))), 0).label("prev_rev"),
                func.coalesce(func.sum(SponsorPayment.net_to_organizer_cents), 0).label("all_rev"),
            )
            .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .where(SponsorshipCategory.event_id.in_(org_event_ids_q))
        )).one()

    async def get_sponsor_count_kpis(
        self, db: AsyncSession, org_event_ids_q, period_start: datetime, prev_start: datetime
    ):
        """Return consolidated sponsor-count row."""
        sb_accepted = SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid])
        sb_cur = SponsorBid.created_at >= period_start
        sb_prev = and_(SponsorBid.created_at >= prev_start, SponsorBid.created_at < period_start)

        return (await db.execute(
            select(
                func.count(func.distinct(case((and_(sb_accepted, sb_cur), SponsorBid.sponsor_user_id)))).label("cur"),
                func.count(func.distinct(case((and_(sb_accepted, sb_prev), SponsorBid.sponsor_user_id)))).label("prev"),
                func.count(func.distinct(case((sb_accepted, SponsorBid.sponsor_user_id)))).label("all"),
            )
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .where(SponsorshipCategory.event_id.in_(org_event_ids_q))
        )).one()

    async def get_event_count_kpis(
        self, db: AsyncSession, org_events_excl_draft, period_start: datetime, prev_start: datetime
    ):
        """Return consolidated event-count row."""
        ev_cur = Event.created_at >= period_start
        ev_prev = and_(Event.created_at >= prev_start, Event.created_at < period_start)

        return (await db.execute(
            select(
                func.count().label("all_events"),
                func.count(case((ev_cur, 1))).label("cur"),
                func.count(case((ev_prev, 1))).label("prev"),
            )
            .select_from(Event)
            .where(Event.id.in_(org_events_excl_draft))
        )).one()

    # ===================================================================
    #  Status Breakdown
    # ===================================================================

    async def get_status_breakdown(self, db: AsyncSession, organizer_id: int) -> list:
        """Return event status breakdown for the organizer."""
        return (await db.execute(
            select(Event.status, func.count().label("cnt"))
            .where(Event.organizer_id == organizer_id)
            .group_by(Event.status)
        )).all()

    # ===================================================================
    #  Top / Trending / Popular events
    # ===================================================================

    async def get_top_events(self, db: AsyncSession, organizer_id: int, limit: int = 5) -> list:
        """Top events by revenue (ticket + funding)."""
        ticket_rev_sub = (
            select(
                TicketSale.event_id,
                func.coalesce(func.sum(TicketSale.net_to_organizer_cents), 0).label("t_rev"),
            )
            .where(TicketSale.status != TicketSaleStatus.cancelled)
            .group_by(TicketSale.event_id)
            .subquery()
        )
        funding_rev_sub = (
            select(
                Funding.event_id,
                func.coalesce(func.sum(Funding.net_to_organizer_cents), 0).label("f_rev"),
            )
            .where(Funding.status == FundingStatus.pledged)
            .group_by(Funding.event_id)
            .subquery()
        )
        top_q = (
            select(
                Event,
                func.coalesce(ticket_rev_sub.c.t_rev, 0).label("t_rev"),
                func.coalesce(funding_rev_sub.c.f_rev, 0).label("f_rev"),
            )
            .outerjoin(ticket_rev_sub, Event.id == ticket_rev_sub.c.event_id)
            .outerjoin(funding_rev_sub, Event.id == funding_rev_sub.c.event_id)
            .where(Event.organizer_id == organizer_id, Event.status != EventStatus.draft)
            .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
            .order_by(
                (func.coalesce(ticket_rev_sub.c.t_rev, 0) + func.coalesce(funding_rev_sub.c.f_rev, 0)).desc()
            )
            .limit(limit)
        )
        return (await db.execute(top_q)).all()

    async def get_trending_events(self, db: AsyncSession, organizer_id: int, limit: int = 5) -> list:
        """Trending events by registration count."""
        trending_q = (
            select(Event)
            .where(Event.organizer_id == organizer_id, Event.status != EventStatus.draft)
            .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
            .order_by(Event.registration_count.desc())
            .limit(limit)
        )
        return list((await db.execute(trending_q)).scalars().all())

    async def get_popular_events(self, db: AsyncSession, organizer_id: int, limit: int = 5) -> list:
        """Popular events by total pledged amount."""
        popular_q = (
            select(Event, func.coalesce(func.sum(Funding.amount_cents), 0).label("total_pledged"))
            .outerjoin(Funding, (Funding.event_id == Event.id) & (Funding.status == FundingStatus.pledged))
            .where(Event.organizer_id == organizer_id, Event.status != EventStatus.draft)
            .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
            .group_by(Event.id)
            .order_by(func.coalesce(func.sum(Funding.amount_cents), 0).desc())
            .limit(limit)
        )
        return (await db.execute(popular_q)).all()

    # ===================================================================
    #  Activity Feed
    # ===================================================================

    async def get_activity_feed(self, db: AsyncSession, org_event_ids_q, limit: int = 10) -> list:
        """Recent activity feed (tickets, pledges, sponsor bids) for the organizer."""
        ticket_feed = (
            select(
                literal("ticket_sale").label("type"),
                TicketSale.event_id.label("event_id"),
                Event.title.label("event_title"),
                User.display_name.label("actor_name"),
                TicketSale.amount_paid_cents.label("amount_cents"),
                literal(None).label("extra"),
                TicketSale.created_at.label("created_at"),
            )
            .join(Event, TicketSale.event_id == Event.id)
            .join(User, TicketSale.user_id == User.id)
            .where(
                TicketSale.event_id.in_(org_event_ids_q),
                TicketSale.status != TicketSaleStatus.cancelled,
            )
        )

        funding_feed = (
            select(
                literal("pledge").label("type"),
                Funding.event_id.label("event_id"),
                Event.title.label("event_title"),
                User.display_name.label("actor_name"),
                Funding.amount_cents.label("amount_cents"),
                literal(None).label("extra"),
                Funding.created_at.label("created_at"),
            )
            .join(Event, Funding.event_id == Event.id)
            .join(User, Funding.user_id == User.id)
            .where(
                Funding.event_id.in_(org_event_ids_q),
                Funding.status == FundingStatus.pledged,
            )
        )

        bid_feed = (
            select(
                literal("sponsor_bid").label("type"),
                SponsorshipCategory.event_id.label("event_id"),
                Event.title.label("event_title"),
                User.display_name.label("actor_name"),
                SponsorBid.amount_cents.label("amount_cents"),
                cast(SponsorBid.status, String).label("extra"),
                SponsorBid.created_at.label("created_at"),
            )
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .join(Event, SponsorshipCategory.event_id == Event.id)
            .join(User, SponsorBid.sponsor_user_id == User.id)
            .where(SponsorshipCategory.event_id.in_(org_event_ids_q))
        )

        combined = union_all(ticket_feed, funding_feed, bid_feed).subquery()
        feed_q = (
            select(combined)
            .order_by(combined.c.created_at.desc())
            .limit(limit)
        )
        return (await db.execute(feed_q)).all()

    # ===================================================================
    #  Time Series
    # ===================================================================

    async def get_time_series_ticket_daily(
        self, db: AsyncSession, org_event_ids_q, start: datetime
    ) -> list:
        """Daily ticket revenue + count for the organizer's events."""
        ticket_day = func.date_trunc("day", TicketSale.created_at)
        return (await db.execute(
            select(
                ticket_day.label("d"),
                func.coalesce(func.sum(TicketSale.net_to_organizer_cents), 0).label("rev"),
                func.count().label("cnt"),
            )
            .where(
                TicketSale.event_id.in_(org_event_ids_q),
                TicketSale.status != TicketSaleStatus.cancelled,
                TicketSale.created_at >= start,
            )
            .group_by(ticket_day)
        )).all()

    async def get_time_series_funding_daily(
        self, db: AsyncSession, org_event_ids_q, start: datetime
    ) -> list:
        """Daily funding revenue + count for the organizer's events."""
        funding_day = func.date_trunc("day", Funding.created_at)
        return (await db.execute(
            select(
                funding_day.label("d"),
                func.coalesce(func.sum(Funding.net_to_organizer_cents), 0).label("rev"),
                func.count().label("cnt"),
            )
            .where(
                Funding.event_id.in_(org_event_ids_q),
                Funding.status == FundingStatus.pledged,
                Funding.created_at >= start,
            )
            .group_by(funding_day)
        )).all()


# Module-level singleton
dashboard_repo = DashboardRepository()
