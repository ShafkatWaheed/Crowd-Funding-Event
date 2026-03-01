"""
Admin: list events for moderation, approve/reject, platform stats, validation warnings,
and the consolidated dashboard endpoint.
"""
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, func, or_, case, cast, Date, literal_column
from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.user import User
from app.services import event as event_service

logger = get_logger("svc.admin")


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
    log_step(logger, "List events for admin", status=status, offset=offset, limit=limit, search=search)
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
    log_step(logger, "Approve or reject event", event_id=event_id, approved=approved)
    from app.core.exceptions import ConflictError
    from app.services.escrow_base import organizer_has_verified_bank

    event = await event_service.get_or_404(db, event_id)
    if approved:
        if not await organizer_has_verified_bank(db, event.organizer_id):
            logger.warning("Approve rejected: organizer lacks verified bank", extra={"event_id": event_id, "organizer_id": event.organizer_id})
            raise ConflictError(
                "Organizer must have a verified bank account before the event can be approved"
            )
        # Event must have a funding goal or at least one ticket tier
        from app.models.ticket import TicketTier
        has_funding = event.funding_goal_cents is not None and event.funding_goal_cents > 0
        tier_count = (await db.execute(
            select(func.count()).select_from(TicketTier).where(TicketTier.event_id == event.id)
        )).scalar_one()
        if not has_funding and tier_count == 0:
            logger.warning("Approve rejected: no funding goal or ticket tiers", extra={"event_id": event_id})
            raise ConflictError(
                "Event must have a funding goal or at least one ticket tier before approval"
            )
        event.status = EventStatus.approved
        logger.info("Event approved", extra={"event_id": event_id})
    else:
        event.status = EventStatus.draft
        logger.info("Event rejected", extra={"event_id": event_id})
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


# ---------------------------------------------------------------------------
# Dashboard (admin home tab) -- consolidated, filterable
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


async def get_dashboard(
    db: AsyncSession,
    period: str = "30d",
    genre: str | None = None,
    status: str | None = None,
) -> dict:
    from app.models.escrow import FundEscrow, EscrowStatus

    now = datetime.now(timezone.utc)
    cutoff = _period_cutoff(period)

    # ── shared event filter ──
    def _event_filter(q):
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

    # subquery: filtered event ids
    filtered_events_sq = _event_filter(select(Event.id)).subquery()

    # ── 1. KPIs ──
    ticket_agg = (
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

    funding_agg = (
        await db.execute(
            select(
                func.coalesce(func.sum(Funding.platform_cut_cents), 0).label("fc"),
                func.coalesce(func.sum(Funding.amount_cents), 0).label("fa"),
                func.count(Funding.id).label("cnt"),
            ).where(Funding.event_id.in_(select(filtered_events_sq.c.id)))
        )
    ).one()

    escrow_agg = (
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

    events_total_q = select(func.count()).select_from(
        _event_filter(select(Event.id)).subquery()
    )
    events_total = (await db.execute(events_total_q)).scalar_one()

    events_live_q = select(func.count()).select_from(
        _event_filter(
            select(Event.id).where(
                Event.status.in_([EventStatus.approved, EventStatus.live]),
                Event.start_time <= now,
                Event.end_time >= now,
            )
        ).subquery()
    )
    events_live = (await db.execute(events_live_q)).scalar_one()

    users_total = (await db.execute(select(func.count()).select_from(User))).scalar_one()

    total_tickets = int(ticket_agg.cnt)
    total_refunded = int(ticket_agg.refunded)
    refund_rate = (total_refunded / total_tickets * 100) if total_tickets > 0 else 0.0
    avg_ticket = int(ticket_agg.ts) // total_tickets if total_tickets > 0 else 0

    funded_events_count = (
        await db.execute(
            select(func.count(func.distinct(Funding.event_id)))
            .where(Funding.event_id.in_(select(filtered_events_sq.c.id)))
        )
    ).scalar_one()
    avg_funding = int(funding_agg.fa) // int(funded_events_count) if funded_events_count > 0 else 0

    # funding goal hit rate
    goal_total = (
        await db.execute(
            select(func.count()).select_from(
                _event_filter(
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
                    _event_filter(
                        select(Event.id).where(Event.funding_goal_cents > 0)
                    )
                ))
                .group_by(Funding.event_id)
            )
        ).all()
        goal_events = {r.event_id: int(r.total) for r in funded_sums}
        goal_rows = (
            await db.execute(
                _event_filter(
                    select(Event.id, Event.funding_goal_cents)
                    .where(Event.funding_goal_cents > 0)
                )
            )
        ).all()
        goal_hit = sum(
            1 for r in goal_rows
            if goal_events.get(r.id, 0) >= (r.funding_goal_cents or 0)
        )
    goal_hit_rate = (goal_hit / goal_total * 100) if goal_total > 0 else 0.0

    kpis = {
        "total_revenue_cents": int(ticket_agg.tc) + int(funding_agg.fc),
        "ticket_commission_cents": int(ticket_agg.tc),
        "funding_commission_cents": int(funding_agg.fc),
        "total_ticket_sales_cents": int(ticket_agg.ts),
        "total_funding_cents": int(funding_agg.fa),
        "escrow_held_cents": int(escrow_agg.held),
        "escrow_released_cents": int(escrow_agg.released),
        "tickets_sold": total_tickets,
        "pledges_made": int(funding_agg.cnt),
        "events_total": int(events_total),
        "events_live": int(events_live),
        "users_total": int(users_total),
        "avg_ticket_price_cents": avg_ticket,
        "avg_funding_per_event_cents": avg_funding,
        "refund_rate_percent": round(refund_rate, 1),
        "funding_goal_hit_rate_percent": round(goal_hit_rate, 1),
    }

    # ── 2. available filters ──
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

    # ── 3. by_genre ──
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
    by_genre = [
        {
            "genre": r.genre or "other",
            "events": int(r.events),
            "revenue_cents": int(r.revenue),
            "tickets": int(r.tickets),
            "funding_cents": int(r.funding),
        }
        for r in by_genre_rows
    ]

    # ── 4. by_status ──
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
    by_status = [
        {
            "status": r.status.value if hasattr(r.status, "value") else str(r.status),
            "count": int(r.cnt),
            "revenue_cents": int(r.revenue),
            "funding_cents": int(r.funding),
        }
        for r in by_status_rows
    ]

    # ── 5. by_escrow_status ──
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
    by_escrow_status = [
        {
            "status": r.status.value if hasattr(r.status, "value") else str(r.status),
            "count": int(r.cnt),
            "total_cents": int(r.total),
        }
        for r in by_escrow_rows
    ]

    # ── 6. time_series ──
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
    time_series = [
        {
            "date": d,
            "revenue_cents": ticket_ts.get(d, {}).get("rev", 0) + funding_ts.get(d, {}).get("frev", 0),
            "tickets_sold": ticket_ts.get(d, {}).get("tix", 0),
            "pledges_count": funding_ts.get(d, {}).get("pl", 0),
        }
        for d in all_dates
    ]

    # ── 7. top events ──
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

    top_events = [
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

    # ── 8. action items ──
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

    action_items = {
        "pending_approval": int(pending_approval),
        "pending_cancellations": int(pending_cancellations),
        "pending_extensions": int(pending_extensions),
        "under_review": int(under_review),
        "pending_refunds": int(pending_refunds),
    }

    return {
        "kpis": kpis,
        "available_filters": {
            "genres": sorted(avail_genres),
            "statuses": sorted(avail_statuses),
        },
        "by_genre": by_genre,
        "by_status": by_status,
        "by_escrow_status": by_escrow_status,
        "time_series": time_series,
        "top_events": top_events,
        "action_items": action_items,
    }
