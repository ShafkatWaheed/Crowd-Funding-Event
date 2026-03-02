"""
Admin data-access layer.

All SQLAlchemy queries for admin user management, event moderation, platform
stats, and the consolidated dashboard live here.
"""
from datetime import datetime, timedelta, timezone

from sqlalchemy import case, cast, Date, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
from app.models.user import User


# ---------------------------------------------------------------------------
# Period helpers (shared with service layer)
# ---------------------------------------------------------------------------

_PERIOD_DELTAS = {
    "7d": timedelta(days=7),
    "30d": timedelta(days=30),
    "90d": timedelta(days=90),
    "130d": timedelta(days=130),
    "1y": timedelta(days=365),
}


def _period_cutoff(period: str) -> datetime | None:
    delta = _PERIOD_DELTAS.get(period)
    if delta is None:
        return None
    return datetime.now(timezone.utc) - delta


class AdminRepository:
    """Pure data-access — no business logic, no side effects."""

    # ===================================================================
    #  User management queries
    # ===================================================================

    async def list_users(
        self,
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

    async def get_user_by_id(self, db: AsyncSession, user_id: int) -> User | None:
        """Get a single user by id."""
        return (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()

    # ===================================================================
    #  Event management queries
    # ===================================================================

    async def list_events(
        self,
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

    async def get_event_for_approval(self, db: AsyncSession, event_id: int) -> Event | None:
        """Get a single event by id (for approval flow)."""
        return (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()

    async def count_tiers(self, db: AsyncSession, event_id: int) -> int:
        """Count ticket tiers for an event."""
        return int((await db.execute(
            select(func.count()).select_from(TicketTier).where(TicketTier.event_id == event_id)
        )).scalar_one())

    async def flush_and_refresh(self, db: AsyncSession, obj) -> None:
        """Flush and refresh a model instance."""
        await db.flush()
        await db.refresh(obj)

    # ===================================================================
    #  Stats & Dashboard aggregation queries
    # ===================================================================

    async def get_stats(self, db: AsyncSession) -> dict:
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

    # -------------------------------------------------------------------
    #  Dashboard sub-queries (each returns raw aggregation data)
    # -------------------------------------------------------------------

    def _build_event_filter(self, cutoff: datetime | None, genre: str | None, status: str | None):
        """Return a callable that applies period/genre/status filters to a query."""
        def _apply(q):
            if cutoff is not None:
                q = q.where(Event.created_at >= cutoff)
            if genre:
                q = q.where(Event.genre == genre)
            if status:
                try:
                    q = q.where(Event.status == EventStatus(status))
                except ValueError:
                    pass
            return q
        return _apply

    def build_filtered_events_sq(self, cutoff: datetime | None, genre: str | None, status: str | None):
        """Build and return the filtered event ids subquery."""
        event_filter = self._build_event_filter(cutoff, genre, status)
        return event_filter(select(Event.id)).subquery()

    async def get_dashboard_ticket_agg(self, db: AsyncSession, filtered_events_sq):
        """Aggregate ticket data for the filtered event set."""
        return (
            await db.execute(
                select(
                    func.coalesce(func.sum(TicketSale.commission_cents), 0).label("tc"),
                    func.coalesce(func.sum(TicketSale.amount_paid_cents), 0).label("ts"),
                    func.count(TicketSale.id).label("cnt"),
                    func.coalesce(
                        func.sum(
                            case(
                                (TicketSale.status.in_([
                                    TicketSaleStatus.refunded,
                                    TicketSaleStatus.refund_processing,
                                    TicketSaleStatus.refund_requested,
                                ]), 1),
                                else_=0,
                            )
                        ), 0
                    ).label("refunded"),
                ).where(TicketSale.event_id.in_(select(filtered_events_sq.c.id)))
            )
        ).one()

    async def get_dashboard_funding_agg(self, db: AsyncSession, filtered_events_sq):
        """Aggregate funding data for the filtered event set."""
        return (
            await db.execute(
                select(
                    func.coalesce(func.sum(Funding.platform_cut_cents), 0).label("fc"),
                    func.coalesce(func.sum(Funding.amount_cents), 0).label("fa"),
                    func.count(Funding.id).label("cnt"),
                ).where(Funding.event_id.in_(select(filtered_events_sq.c.id)))
            )
        ).one()

    async def get_dashboard_escrow_agg(self, db: AsyncSession, filtered_events_sq):
        """Aggregate escrow data for the filtered event set."""
        from app.models.escrow import FundEscrow

        return (
            await db.execute(
                select(
                    func.coalesce(func.sum(FundEscrow.total_held_cents), 0).label("held"),
                    func.coalesce(
                        func.sum(
                            FundEscrow.stage1_released_cents
                            + FundEscrow.stage2_released_cents
                            + FundEscrow.stage3_released_cents
                        ), 0
                    ).label("released"),
                ).where(FundEscrow.event_id.in_(select(filtered_events_sq.c.id)))
            )
        ).one()

    async def get_dashboard_event_counts(
        self, db: AsyncSession, event_filter, now: datetime
    ) -> tuple[int, int, int]:
        """Return (events_total, events_live, users_total) for the dashboard."""
        events_total_q = select(func.count()).select_from(
            event_filter(select(Event.id)).subquery()
        )
        events_total = (await db.execute(events_total_q)).scalar_one()

        events_live_q = select(func.count()).select_from(
            event_filter(
                select(Event.id).where(
                    Event.status.in_([EventStatus.approved, EventStatus.live]),
                    Event.start_time <= now,
                    Event.end_time >= now,
                )
            ).subquery()
        )
        events_live = (await db.execute(events_live_q)).scalar_one()

        users_total = (await db.execute(select(func.count()).select_from(User))).scalar_one()

        return int(events_total), int(events_live), int(users_total)

    async def get_dashboard_funding_goal_stats(
        self, db: AsyncSession, event_filter, filtered_events_sq
    ) -> tuple[int, int, int]:
        """
        Return (funded_events_count, goal_total, goal_hit) for the dashboard.
        """
        funded_events_count = (
            await db.execute(
                select(func.count(func.distinct(Funding.event_id)))
                .where(Funding.event_id.in_(select(filtered_events_sq.c.id)))
            )
        ).scalar_one()

        goal_total = (
            await db.execute(
                select(func.count()).select_from(
                    event_filter(
                        select(Event.id).where(Event.funding_goal_cents > 0)
                    ).subquery()
                )
            )
        ).scalar_one()

        goal_hit = 0
        if goal_total > 0:
            funded_sums = (
                await db.execute(
                    select(
                        Funding.event_id,
                        func.sum(Funding.amount_cents).label("total"),
                    )
                    .where(Funding.event_id.in_(
                        event_filter(
                            select(Event.id).where(Event.funding_goal_cents > 0)
                        )
                    ))
                    .group_by(Funding.event_id)
                )
            ).all()
            goal_events = {r.event_id: int(r.total) for r in funded_sums}
            goal_rows = (
                await db.execute(
                    event_filter(
                        select(Event.id, Event.funding_goal_cents)
                        .where(Event.funding_goal_cents > 0)
                    )
                )
            ).all()
            goal_hit = sum(
                1 for r in goal_rows
                if goal_events.get(r.id, 0) >= (r.funding_goal_cents or 0)
            )

        return int(funded_events_count), int(goal_total), goal_hit

    async def get_dashboard_available_filters(
        self, db: AsyncSession, cutoff: datetime | None, genre: str | None
    ) -> tuple[list[str], list[str]]:
        """Return (available_genres, available_statuses) for the dashboard filters."""
        period_only = select(Event.id)
        if cutoff is not None:
            period_only = period_only.where(Event.created_at >= cutoff)

        avail_genres = [
            r[0] for r in (
                await db.execute(
                    select(func.distinct(Event.genre))
                    .where(Event.genre.isnot(None))
                    .where(Event.id.in_(period_only))
                )
            ).all() if r[0]
        ]

        genre_status_q = select(func.distinct(Event.status)).where(Event.id.in_(period_only))
        if genre:
            genre_status_q = genre_status_q.where(Event.genre == genre)
        avail_statuses = [
            r[0].value if hasattr(r[0], "value") else str(r[0])
            for r in (await db.execute(genre_status_q)).all()
        ]

        return sorted(avail_genres), sorted(avail_statuses)

    async def get_dashboard_by_genre(self, db: AsyncSession, filtered_events_sq) -> list[dict]:
        """Return revenue/ticket/funding breakdown by genre."""
        by_genre_rows = (
            await db.execute(
                select(
                    Event.genre,
                    func.count(func.distinct(Event.id)).label("events"),
                    func.coalesce(func.sum(TicketSale.commission_cents), 0).label("revenue"),
                    func.count(TicketSale.id).label("tickets"),
                    func.coalesce(func.sum(Funding.amount_cents), 0).label("funding"),
                )
                .outerjoin(TicketSale, TicketSale.event_id == Event.id)
                .outerjoin(Funding, Funding.event_id == Event.id)
                .where(Event.id.in_(select(filtered_events_sq.c.id)), Event.genre.isnot(None))
                .group_by(Event.genre)
                .order_by(func.coalesce(func.sum(TicketSale.commission_cents), 0).desc())
            )
        ).all()
        return [
            {
                "genre": r.genre or "other",
                "events": int(r.events),
                "revenue_cents": int(r.revenue),
                "tickets": int(r.tickets),
                "funding_cents": int(r.funding),
            }
            for r in by_genre_rows
        ]

    async def get_dashboard_by_status(self, db: AsyncSession, filtered_events_sq) -> list[dict]:
        """Return event count / revenue / funding breakdown by status."""
        by_status_rows = (
            await db.execute(
                select(
                    Event.status,
                    func.count(Event.id).label("cnt"),
                    func.coalesce(func.sum(TicketSale.commission_cents), 0).label("revenue"),
                    func.coalesce(func.sum(Funding.amount_cents), 0).label("funding"),
                )
                .outerjoin(TicketSale, TicketSale.event_id == Event.id)
                .outerjoin(Funding, Funding.event_id == Event.id)
                .where(Event.id.in_(select(filtered_events_sq.c.id)))
                .group_by(Event.status)
            )
        ).all()
        return [
            {
                "status": r.status.value if hasattr(r.status, "value") else str(r.status),
                "count": int(r.cnt),
                "revenue_cents": int(r.revenue),
                "funding_cents": int(r.funding),
            }
            for r in by_status_rows
        ]

    async def get_dashboard_by_escrow_status(self, db: AsyncSession, filtered_events_sq) -> list[dict]:
        """Return escrow count / total breakdown by escrow status."""
        from app.models.escrow import FundEscrow

        by_escrow_rows = (
            await db.execute(
                select(
                    FundEscrow.status,
                    func.count(FundEscrow.id).label("cnt"),
                    func.coalesce(func.sum(FundEscrow.total_held_cents), 0).label("total"),
                )
                .where(FundEscrow.event_id.in_(select(filtered_events_sq.c.id)))
                .group_by(FundEscrow.status)
            )
        ).all()
        return [
            {
                "status": r.status.value if hasattr(r.status, "value") else str(r.status),
                "count": int(r.cnt),
                "total_cents": int(r.total),
            }
            for r in by_escrow_rows
        ]

    async def get_dashboard_time_series(
        self, db: AsyncSession, filtered_events_sq, cutoff: datetime | None
    ) -> list[dict]:
        """Return daily time-series of ticket + funding revenue."""
        ts_date = cast(TicketSale.created_at, Date)
        ts_q = (
            select(
                ts_date.label("d"),
                func.coalesce(func.sum(TicketSale.commission_cents), 0).label("rev"),
                func.count(TicketSale.id).label("tix"),
            )
            .where(TicketSale.event_id.in_(select(filtered_events_sq.c.id)))
            .group_by(ts_date)
            .order_by(ts_date)
        )
        if cutoff is not None:
            ts_q = ts_q.where(TicketSale.created_at >= cutoff)
        ticket_ts = {str(r.d): {"rev": int(r.rev), "tix": int(r.tix)} for r in (await db.execute(ts_q)).all()}

        fs_date = cast(Funding.created_at, Date)
        fs_q = (
            select(
                fs_date.label("d"),
                func.coalesce(func.sum(Funding.platform_cut_cents), 0).label("frev"),
                func.count(Funding.id).label("pl"),
            )
            .where(Funding.event_id.in_(select(filtered_events_sq.c.id)))
            .group_by(fs_date)
            .order_by(fs_date)
        )
        if cutoff is not None:
            fs_q = fs_q.where(Funding.created_at >= cutoff)
        funding_ts = {str(r.d): {"frev": int(r.frev), "pl": int(r.pl)} for r in (await db.execute(fs_q)).all()}

        all_dates = sorted(set(ticket_ts.keys()) | set(funding_ts.keys()))
        return [
            {
                "date": d,
                "revenue_cents": ticket_ts.get(d, {}).get("rev", 0) + funding_ts.get(d, {}).get("frev", 0),
                "tickets_sold": ticket_ts.get(d, {}).get("tix", 0),
                "pledges_count": funding_ts.get(d, {}).get("pl", 0),
            }
            for d in all_dates
        ]

    async def get_dashboard_top_events(self, db: AsyncSession, filtered_events_sq) -> list[dict]:
        """Return top 10 events by ticket commission revenue."""
        top_sq = (
            select(
                Event.id,
                Event.title,
                Event.genre,
                Event.status,
                func.coalesce(func.sum(TicketSale.commission_cents), 0).label("rev"),
                func.count(TicketSale.id).label("tix"),
            )
            .outerjoin(TicketSale, TicketSale.event_id == Event.id)
            .where(Event.id.in_(select(filtered_events_sq.c.id)))
            .group_by(Event.id, Event.title, Event.genre, Event.status)
            .order_by(func.coalesce(func.sum(TicketSale.commission_cents), 0).desc())
            .limit(10)
        )
        top_rows = (await db.execute(top_sq)).all()

        top_event_ids = [r.id for r in top_rows]
        funding_by_event: dict[int, int] = {}
        if top_event_ids:
            fund_rows = (
                await db.execute(
                    select(
                        Funding.event_id,
                        func.coalesce(func.sum(Funding.amount_cents), 0).label("f"),
                    )
                    .where(Funding.event_id.in_(top_event_ids))
                    .group_by(Funding.event_id)
                )
            ).all()
            funding_by_event = {r.event_id: int(r.f) for r in fund_rows}

        return [
            {
                "id": r.id,
                "title": r.title,
                "genre": r.genre,
                "status": r.status.value if hasattr(r.status, "value") else str(r.status),
                "revenue_cents": int(r.rev),
                "tickets_sold": int(r.tix),
                "funding_cents": funding_by_event.get(r.id, 0),
            }
            for r in top_rows
        ]

    async def get_dashboard_action_items(self, db: AsyncSession) -> dict:
        """Return counts of items requiring admin attention."""
        pending_approval = (
            await db.execute(
                select(func.count()).select_from(Event)
                .where(Event.status == EventStatus.pending_approval)
            )
        ).scalar_one()
        pending_cancellations = (
            await db.execute(
                select(func.count()).select_from(Event)
                .where(Event.pending_cancellation.isnot(None))
            )
        ).scalar_one()
        pending_extensions = (
            await db.execute(
                select(func.count()).select_from(Event)
                .where(Event.pending_extension.isnot(None))
            )
        ).scalar_one()
        under_review = (
            await db.execute(
                select(func.count()).select_from(Event)
                .where(Event.status == EventStatus.under_review)
            )
        ).scalar_one()
        pending_refunds = (
            await db.execute(
                select(func.count()).select_from(TicketSale)
                .where(TicketSale.status.in_([
                    TicketSaleStatus.refund_requested,
                    TicketSaleStatus.refund_processing,
                ]))
            )
        ).scalar_one()

        return {
            "pending_approval": int(pending_approval),
            "pending_cancellations": int(pending_cancellations),
            "pending_extensions": int(pending_extensions),
            "under_review": int(under_review),
            "pending_refunds": int(pending_refunds),
        }


# Module-level singleton
admin_repo = AdminRepository()
