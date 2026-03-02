"""
Organizer dashboard aggregation queries: KPIs with deltas, status breakdown,
top/trending events, recent activity feed, and time-series data.
"""
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.dashboard_repo import dashboard_repo


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

    org_event_ids_q = dashboard_repo.build_org_event_ids_query(
        organizer_id, event_id=event_id, status_filter=status_filter, genre=genre,
    )
    org_events_excl_draft = dashboard_repo.build_org_events_excl_draft(org_event_ids_q)

    # -- Consolidated KPI queries via repo --
    ts = await dashboard_repo.get_ticket_kpis(db, org_event_ids_q, period_start, prev_start)
    fs = await dashboard_repo.get_funding_kpis(db, org_event_ids_q, period_start, prev_start)
    sp = await dashboard_repo.get_sponsor_payment_kpis(db, org_event_ids_q, period_start, prev_start)
    spc = await dashboard_repo.get_sponsor_count_kpis(db, org_event_ids_q, period_start, prev_start)
    ev = await dashboard_repo.get_event_count_kpis(db, org_events_excl_draft, period_start, prev_start)

    # -- Assemble KPIs --
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

    # -- Status Breakdown --
    status_rows = await dashboard_repo.get_status_breakdown(db, organizer_id)
    status_breakdown = [{"status": r.status.value, "count": r.cnt} for r in status_rows]

    # -- Top 5 Events by Revenue --
    top_rows = await dashboard_repo.get_top_events(db, organizer_id, limit=5)
    top_events_raw = [row[0] for row in top_rows]

    # -- Trending Events (by registration_count) --
    trending_raw = await dashboard_repo.get_trending_events(db, organizer_id, limit=5)

    # -- Popular Events (by total pledged) --
    popular_rows = await dashboard_repo.get_popular_events(db, organizer_id, limit=5)
    popular_raw = [row[0] for row in popular_rows]

    # -- Recent Activity Feed (10 items) --
    feed_rows = await dashboard_repo.get_activity_feed(db, org_event_ids_q, limit=10)
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
    org_event_ids_q = dashboard_repo.build_org_event_ids_query(
        organizer_id, event_id=event_id, status_filter=status_filter, genre=genre,
    )

    ticket_daily = await dashboard_repo.get_time_series_ticket_daily(db, org_event_ids_q, start)
    funding_daily = await dashboard_repo.get_time_series_funding_daily(db, org_event_ids_q, start)

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
