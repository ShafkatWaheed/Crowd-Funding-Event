"""
Organizer dashboard aggregation queries: KPIs with deltas, status breakdown,
top/trending events, recent activity feed, and time-series data.
"""
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import and_, func, select, union_all, literal, case, cast, String, Integer
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
    genre: str | None = None,
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
    if genre:
        org_event_ids_q = org_event_ids_q.where(Event.genre == genre)
    org_events_excl_draft = org_event_ids_q.where(Event.status != EventStatus.draft)

    # ── Consolidated TicketSale KPIs (1 query) ──────────────────────────
    t_ref_statuses = [
        TicketSaleStatus.refunded,
        TicketSaleStatus.refund_requested,
        TicketSaleStatus.refund_processing,
    ]
    t_cur = TicketSale.created_at >= period_start
    t_prev = and_(TicketSale.created_at >= prev_start, TicketSale.created_at < period_start)
    t_active = TicketSale.status != TicketSaleStatus.cancelled
    t_refunded = TicketSale.status.in_(t_ref_statuses)

    ts = (await db.execute(
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

    # ── Consolidated Funding KPIs (1 query) ──────────────────────────────
    f_pledged = Funding.status == FundingStatus.pledged
    f_cur = Funding.created_at >= period_start
    f_prev = and_(Funding.created_at >= prev_start, Funding.created_at < period_start)
    f_ref_statuses = [FundingStatus.refunded, FundingStatus.refund_processing]
    f_refunded = Funding.status.in_(f_ref_statuses)

    fs = (await db.execute(
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

    # ── Consolidated SponsorPayment revenue (1 query) ────────────────────
    sp_cur = SponsorPayment.created_at >= period_start
    sp_prev = and_(SponsorPayment.created_at >= prev_start, SponsorPayment.created_at < period_start)

    sp = (await db.execute(
        select(
            func.coalesce(func.sum(case((sp_cur, SponsorPayment.net_to_organizer_cents))), 0).label("cur_rev"),
            func.coalesce(func.sum(case((sp_prev, SponsorPayment.net_to_organizer_cents))), 0).label("prev_rev"),
            func.coalesce(func.sum(SponsorPayment.net_to_organizer_cents), 0).label("all_rev"),
        )
        .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(SponsorshipCategory.event_id.in_(org_event_ids_q))
    )).one()

    # ── Consolidated Sponsor count (1 query) ─────────────────────────────
    sb_accepted = SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid])
    sb_cur = SponsorBid.created_at >= period_start
    sb_prev = and_(SponsorBid.created_at >= prev_start, SponsorBid.created_at < period_start)

    spc = (await db.execute(
        select(
            func.count(func.distinct(case((and_(sb_accepted, sb_cur), SponsorBid.sponsor_user_id)))).label("cur"),
            func.count(func.distinct(case((and_(sb_accepted, sb_prev), SponsorBid.sponsor_user_id)))).label("prev"),
            func.count(func.distinct(case((sb_accepted, SponsorBid.sponsor_user_id)))).label("all"),
        )
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(SponsorshipCategory.event_id.in_(org_event_ids_q))
    )).one()

    # ── Consolidated Event count (1 query) ───────────────────────────────
    ev_cur = Event.created_at >= period_start
    ev_prev = and_(Event.created_at >= prev_start, Event.created_at < period_start)

    ev = (await db.execute(
        select(
            func.count().label("all_events"),
            func.count(case((ev_cur, 1))).label("cur"),
            func.count(case((ev_prev, 1))).label("prev"),
        )
        .select_from(Event)
        .where(Event.id.in_(org_events_excl_draft))
    )).one()

    # ── Assemble KPIs ────────────────────────────────────────────────────
    cur_revenue = int(ts.cur_rev) + int(fs.cur_rev) + int(sp.cur_rev)
    prev_revenue = int(ts.prev_rev) + int(fs.prev_rev) + int(sp.prev_rev)
    all_time_revenue = int(ts.all_rev) + int(fs.all_rev) + int(sp.all_rev)

    all_tickets = int(ts.all_sold)
    all_backers = int(fs.all_backers)

    total_transactions = int(ts.all_total) + int(fs.all_total)
    total_refunds = int(ts.all_refunded) + int(fs.all_refunded)
    refund_rate_all = round((total_refunds / total_transactions) * 100, 1) if total_transactions > 0 else 0.0

    cur_ref_total = int(ts.cur_total) + int(fs.cur_total)
    cur_ref_refunds = int(ts.cur_refunded) + int(fs.cur_refunded)
    cur_refund_rate = round((cur_ref_refunds / cur_ref_total) * 100, 1) if cur_ref_total > 0 else 0.0

    prev_ref_total = int(ts.prev_total) + int(fs.prev_total)
    prev_ref_refunds = int(ts.prev_refunded) + int(fs.prev_refunded)
    prev_refund_rate = round((prev_ref_refunds / prev_ref_total) * 100, 1) if prev_ref_total > 0 else 0.0

    def _delta(cur: int | float, prev: int | float) -> float | None:
        if prev == 0:
            return None if cur == 0 else 100.0
        return round(((cur - prev) / prev) * 100, 1)

    kpis = {
        "total_revenue": {"value": all_time_revenue, "delta_percent": _delta(cur_revenue, prev_revenue)},
        "tickets_sold": {"value": all_tickets, "delta_percent": _delta(int(ts.cur_sold), int(ts.prev_sold))},
        "total_backers": {"value": all_backers, "delta_percent": _delta(int(fs.cur_backers), int(fs.prev_backers))},
        "total_events": {"value": int(ev.all_events), "delta_percent": _delta(int(ev.cur), int(ev.prev))},
        "total_sponsors": {"value": int(spc.all), "delta_percent": _delta(int(spc.cur), int(spc.prev))},
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
    genre: str | None = None,
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
    if genre:
        org_event_ids_q = org_event_ids_q.where(Event.genre == genre)

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
