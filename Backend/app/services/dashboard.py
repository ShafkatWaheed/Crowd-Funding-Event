"""
Organizer dashboard aggregation queries: KPIs with deltas, status breakdown,
top/trending events, recent activity feed, and time-series data.
"""
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import func, select, union_all, literal, case, cast, String, Integer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.sponsor import BidStatus, SponsorBid, SponsorshipCategory, SponsorPayment
from app.models.user import User


async def get_organizer_dashboard(
    db: AsyncSession,
    organizer_id: int,
    delta_days: int = 30,
    status_filter: str | None = None,
    event_id: int | None = None,
) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    period_start = now - timedelta(days=delta_days)
    prev_start = period_start - timedelta(days=delta_days)

    org_event_ids_q = select(Event.id).where(Event.organizer_id == organizer_id)
    if event_id is not None:
        org_event_ids_q = org_event_ids_q.where(Event.id == event_id)
    elif status_filter:
        try:
            status_enum = EventStatus(status_filter)
            org_event_ids_q = org_event_ids_q.where(Event.status == status_enum)
        except ValueError:
            pass
    org_events_excl_draft = org_event_ids_q.where(Event.status != EventStatus.draft)

    # ── KPI: Total Revenue ──────────────────────────────────────────────
    async def _revenue(start: datetime, end: datetime) -> int:
        t_rev = (await db.execute(
            select(func.coalesce(func.sum(TicketSale.net_to_organizer_cents), 0))
            .where(
                TicketSale.event_id.in_(org_event_ids_q),
                TicketSale.status != TicketSaleStatus.cancelled,
                TicketSale.created_at >= start,
                TicketSale.created_at < end,
            )
        )).scalar_one()
        f_rev = (await db.execute(
            select(func.coalesce(func.sum(Funding.net_to_organizer_cents), 0))
            .where(
                Funding.event_id.in_(org_event_ids_q),
                Funding.status == FundingStatus.pledged,
                Funding.created_at >= start,
                Funding.created_at < end,
            )
        )).scalar_one()
        sp_rev = (await db.execute(
            select(func.coalesce(func.sum(SponsorPayment.net_to_organizer_cents), 0))
            .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorshipCategory.event_id.in_(org_event_ids_q),
                SponsorPayment.created_at >= start,
                SponsorPayment.created_at < end,
            )
        )).scalar_one()
        return int(t_rev) + int(f_rev) + int(sp_rev)

    cur_revenue = await _revenue(period_start, now)
    prev_revenue = await _revenue(prev_start, period_start)

    total_revenue_all = (await db.execute(
        select(func.coalesce(func.sum(TicketSale.net_to_organizer_cents), 0))
        .where(TicketSale.event_id.in_(org_event_ids_q), TicketSale.status != TicketSaleStatus.cancelled)
    )).scalar_one()
    total_funding_all = (await db.execute(
        select(func.coalesce(func.sum(Funding.net_to_organizer_cents), 0))
        .where(Funding.event_id.in_(org_event_ids_q), Funding.status == FundingStatus.pledged)
    )).scalar_one()
    total_sponsor_all = (await db.execute(
        select(func.coalesce(func.sum(SponsorPayment.net_to_organizer_cents), 0))
        .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(SponsorshipCategory.event_id.in_(org_event_ids_q))
    )).scalar_one()
    all_time_revenue = int(total_revenue_all) + int(total_funding_all) + int(total_sponsor_all)

    # ── KPI: Tickets Sold ───────────────────────────────────────────────
    async def _tickets(start: datetime, end: datetime) -> int:
        return int((await db.execute(
            select(func.count())
            .select_from(TicketSale)
            .where(
                TicketSale.event_id.in_(org_event_ids_q),
                TicketSale.status != TicketSaleStatus.cancelled,
                TicketSale.created_at >= start,
                TicketSale.created_at < end,
            )
        )).scalar_one())

    cur_tickets = await _tickets(period_start, now)
    prev_tickets = await _tickets(prev_start, period_start)
    all_tickets = int((await db.execute(
        select(func.count()).select_from(TicketSale)
        .where(TicketSale.event_id.in_(org_event_ids_q), TicketSale.status != TicketSaleStatus.cancelled)
    )).scalar_one())

    # ── KPI: Total Backers ──────────────────────────────────────────────
    async def _backers(start: datetime, end: datetime) -> int:
        return int((await db.execute(
            select(func.count())
            .select_from(Funding)
            .where(
                Funding.event_id.in_(org_event_ids_q),
                Funding.status == FundingStatus.pledged,
                Funding.created_at >= start,
                Funding.created_at < end,
            )
        )).scalar_one())

    cur_backers = await _backers(period_start, now)
    prev_backers = await _backers(prev_start, period_start)
    all_backers = int((await db.execute(
        select(func.count()).select_from(Funding)
        .where(Funding.event_id.in_(org_event_ids_q), Funding.status == FundingStatus.pledged)
    )).scalar_one())

    # ── KPI: Total Events ──────────────────────────────────────────────
    all_events = int((await db.execute(
        select(func.count()).select_from(Event)
        .where(Event.id.in_(org_events_excl_draft))
    )).scalar_one())

    async def _events_created(start: datetime, end: datetime) -> int:
        return int((await db.execute(
            select(func.count()).select_from(Event)
            .where(
                Event.id.in_(org_events_excl_draft),
                Event.created_at >= start,
                Event.created_at < end,
            )
        )).scalar_one())

    cur_events = await _events_created(period_start, now)
    prev_events = await _events_created(prev_start, period_start)

    # ── KPI: Total Sponsors ─────────────────────────────────────────────
    sponsor_base = (
        select(func.count(func.distinct(SponsorBid.sponsor_user_id)))
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorshipCategory.event_id.in_(org_event_ids_q),
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid]),
        )
    )

    async def _sponsors(start: datetime, end: datetime) -> int:
        return int((await db.execute(
            sponsor_base.where(
                SponsorBid.created_at >= start,
                SponsorBid.created_at < end,
            )
        )).scalar_one())

    cur_sponsors = await _sponsors(period_start, now)
    prev_sponsors = await _sponsors(prev_start, period_start)
    all_sponsors = int((await db.execute(sponsor_base)).scalar_one())

    # ── KPI: Refund Rate ────────────────────────────────────────────────
    total_tickets_all = int((await db.execute(
        select(func.count()).select_from(TicketSale)
        .where(TicketSale.event_id.in_(org_event_ids_q))
    )).scalar_one())
    refunded_tickets_all = int((await db.execute(
        select(func.count()).select_from(TicketSale)
        .where(
            TicketSale.event_id.in_(org_event_ids_q),
            TicketSale.status.in_([
                TicketSaleStatus.refunded,
                TicketSaleStatus.refund_requested,
                TicketSaleStatus.refund_processing,
            ]),
        )
    )).scalar_one())
    total_pledges_all = int((await db.execute(
        select(func.count()).select_from(Funding)
        .where(Funding.event_id.in_(org_event_ids_q))
    )).scalar_one())
    refunded_pledges_all = int((await db.execute(
        select(func.count()).select_from(Funding)
        .where(
            Funding.event_id.in_(org_event_ids_q),
            Funding.status.in_([
                FundingStatus.refunded,
                FundingStatus.refund_processing,
            ]),
        )
    )).scalar_one())

    total_transactions = total_tickets_all + total_pledges_all
    total_refunds = refunded_tickets_all + refunded_pledges_all
    refund_rate_all = round((total_refunds / total_transactions) * 100, 1) if total_transactions > 0 else 0.0

    async def _refund_rate(start: datetime, end: datetime) -> float:
        t_total = int((await db.execute(
            select(func.count()).select_from(TicketSale)
            .where(TicketSale.event_id.in_(org_event_ids_q), TicketSale.created_at >= start, TicketSale.created_at < end)
        )).scalar_one())
        t_ref = int((await db.execute(
            select(func.count()).select_from(TicketSale)
            .where(
                TicketSale.event_id.in_(org_event_ids_q),
                TicketSale.status.in_([TicketSaleStatus.refunded, TicketSaleStatus.refund_requested, TicketSaleStatus.refund_processing]),
                TicketSale.created_at >= start, TicketSale.created_at < end,
            )
        )).scalar_one())
        p_total = int((await db.execute(
            select(func.count()).select_from(Funding)
            .where(Funding.event_id.in_(org_event_ids_q), Funding.created_at >= start, Funding.created_at < end)
        )).scalar_one())
        p_ref = int((await db.execute(
            select(func.count()).select_from(Funding)
            .where(
                Funding.event_id.in_(org_event_ids_q),
                Funding.status.in_([FundingStatus.refunded, FundingStatus.refund_processing]),
                Funding.created_at >= start, Funding.created_at < end,
            )
        )).scalar_one())
        total = t_total + p_total
        refs = t_ref + p_ref
        return round((refs / total) * 100, 1) if total > 0 else 0.0

    cur_refund_rate = await _refund_rate(period_start, now)
    prev_refund_rate = await _refund_rate(prev_start, period_start)

    def _delta(cur: int | float, prev: int | float) -> float | None:
        if prev == 0:
            return None if cur == 0 else 100.0
        return round(((cur - prev) / prev) * 100, 1)

    kpis = {
        "total_revenue": {"value": all_time_revenue, "delta_percent": _delta(cur_revenue, prev_revenue)},
        "tickets_sold": {"value": all_tickets, "delta_percent": _delta(cur_tickets, prev_tickets)},
        "total_backers": {"value": all_backers, "delta_percent": _delta(cur_backers, prev_backers)},
        "total_events": {"value": all_events, "delta_percent": _delta(cur_events, prev_events)},
        "total_sponsors": {"value": all_sponsors, "delta_percent": _delta(cur_sponsors, prev_sponsors)},
        "refund_rate": {"value": refund_rate_all, "delta_percent": _delta(cur_refund_rate, prev_refund_rate)},
    }

    # ── Status Breakdown ────────────────────────────────────────────────
    status_rows = (await db.execute(
        select(Event.status, func.count().label("cnt"))
        .where(Event.organizer_id == organizer_id)
        .group_by(Event.status)
    )).all()
    status_breakdown = [{"status": r.status.value, "count": r.cnt} for r in status_rows]

    # ── Top 5 Events by Revenue ─────────────────────────────────────────
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
        .limit(5)
    )
    top_rows = (await db.execute(top_q)).all()
    top_events_raw = [row[0] for row in top_rows]

    # ── Trending Events (by registration_count) ────────────────────────
    trending_q = (
        select(Event)
        .where(Event.organizer_id == organizer_id, Event.status != EventStatus.draft)
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .order_by(Event.registration_count.desc())
        .limit(5)
    )
    trending_raw = (await db.execute(trending_q)).scalars().all()

    # ── Popular Events (by total pledged) ──────────────────────────────
    popular_q = (
        select(Event, func.coalesce(func.sum(Funding.amount_cents), 0).label("total_pledged"))
        .outerjoin(Funding, (Funding.event_id == Event.id) & (Funding.status == FundingStatus.pledged))
        .where(Event.organizer_id == organizer_id, Event.status != EventStatus.draft)
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .group_by(Event.id)
        .order_by(func.coalesce(func.sum(Funding.amount_cents), 0).desc())
        .limit(5)
    )
    popular_rows = (await db.execute(popular_q)).all()
    popular_raw = [row[0] for row in popular_rows]

    # ── Recent Activity Feed (10 items) ─────────────────────────────────
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
        .limit(10)
    )
    feed_rows = (await db.execute(feed_q)).all()
    recent_activity = []
    for r in feed_rows:
        extra_val = r.extra
        if extra_val is not None:
            extra_val = {"bid_status": str(extra_val)}
        recent_activity.append({
            "type": r.type,
            "event_id": r.event_id,
            "event_title": r.event_title,
            "actor_name": r.actor_name or "Anonymous",
            "amount_cents": int(r.amount_cents),
            "extra": extra_val,
            "created_at": r.created_at,
        })

    return {
        **kpis,
        "status_breakdown": status_breakdown,
        "top_events": top_events_raw,
        "trending_events": list(trending_raw),
        "popular_events": popular_raw,
        "recent_activity": recent_activity,
    }


async def get_organizer_time_series(
    db: AsyncSession,
    organizer_id: int,
    days: int = 30,
    status_filter: str | None = None,
    event_id: int | None = None,
) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)
    org_event_ids_q = select(Event.id).where(Event.organizer_id == organizer_id)
    if event_id is not None:
        org_event_ids_q = org_event_ids_q.where(Event.id == event_id)
    elif status_filter:
        try:
            status_enum = EventStatus(status_filter)
            org_event_ids_q = org_event_ids_q.where(Event.status == status_enum)
        except ValueError:
            pass

    ticket_day = func.date_trunc("day", TicketSale.created_at)
    ticket_daily = (await db.execute(
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

    funding_day = func.date_trunc("day", Funding.created_at)
    funding_daily = (await db.execute(
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

    t_map: dict[str, dict] = {}
    for r in ticket_daily:
        key = r.d.strftime("%Y-%m-%d")
        t_map[key] = {"rev": int(r.rev), "tickets": int(r.cnt)}
    f_map: dict[str, dict] = {}
    for r in funding_daily:
        key = r.d.strftime("%Y-%m-%d")
        f_map[key] = {"rev": int(r.rev), "pledges": int(r.cnt)}

    points = []
    for i in range(days):
        d = (start + timedelta(days=i + 1)).strftime("%Y-%m-%d")
        t = t_map.get(d, {"rev": 0, "tickets": 0})
        f = f_map.get(d, {"rev": 0, "pledges": 0})
        points.append({
            "date": d,
            "revenue_cents": t["rev"] + f["rev"],
            "tickets_sold": t["tickets"],
            "pledges_count": f["pledges"],
        })

    granularity = "daily"
    if days >= 90:
        weekly: list[dict] = []
        for i in range(0, len(points), 7):
            chunk = points[i:i + 7]
            weekly.append({
                "date": chunk[0]["date"],
                "revenue_cents": sum(p["revenue_cents"] for p in chunk),
                "tickets_sold": sum(p["tickets_sold"] for p in chunk),
                "pledges_count": sum(p["pledges_count"] for p in chunk),
            })
        points = weekly
        granularity = "weekly"

    return {"points": points, "granularity": granularity}
