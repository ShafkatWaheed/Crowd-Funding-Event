"""Organizer and public sponsor queries: bid events, sponsorship available, organizer sponsors, paid sponsors."""
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event
from app.models.sponsor import BidStatus
from app.repositories.sponsor_repo import sponsor_repo

from app.services.sponsor.profile import get_profile


async def get_sponsor_bid_events(db: AsyncSession, sponsor_user_id: int) -> list[Event]:
    """Return distinct events where this sponsor has placed at least one active bid."""
    return await sponsor_repo.get_sponsor_bid_events(db, sponsor_user_id)


async def get_sponsor_bids_detail_for_admin(
    db: AsyncSession, sponsor_user_id: int
) -> list[dict]:
    """Return events with bid details for a sponsor (admin user detail)."""
    events = await sponsor_repo.get_sponsor_bid_events(db, sponsor_user_id)
    if not events:
        return []

    event_ids = [e.id for e in events]
    all_bid_rows = await sponsor_repo.get_sponsor_bids_detail_rows(db, event_ids, sponsor_user_id)

    bids_by_event: dict[int, list] = {}
    for r in all_bid_rows:
        bids_by_event.setdefault(r.event_id, []).append({
            "bid_id": r.bid_id,
            "category_id": r.cat_id,
            "category_name": r.cat_name,
            "amount_cents": r.amount_cents,
            "status": r.status.value if hasattr(r.status, "value") else str(r.status),
            "can_refund": r.status == BidStatus.paid,
        })

    return [
        {"event_id": e.id, "event_title": e.title, "bids": bids_by_event.get(e.id, [])}
        for e in events
    ]


async def get_sponsor_bid_summary_for_event(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> dict:
    """Return bid counts by status for a sponsor on a given event."""
    rows = await sponsor_repo.get_sponsor_bid_summary_rows(db, event_id, sponsor_user_id)
    counts = {"pending": 0, "accepted": 0, "rejected": 0, "paid": 0, "withdrawn": 0}
    for row in rows:
        status_val = row[0].value if hasattr(row[0], 'value') else str(row[0])
        if status_val in counts:
            counts[status_val] += 1
    return counts


async def get_events_with_sponsorship_available(
    db: AsyncSession,
    sponsor_user_id: int | None = None,
    exclude_my_bids: bool = False,
) -> list[dict]:
    """Return events that have at least one sponsorship category with open spots."""
    events = await sponsor_repo.get_events_with_open_sponsorship(
        db, sponsor_user_id=sponsor_user_id, exclude_my_bids=exclude_my_bids
    )

    results = []
    for e in events:
        cats = [
            {
                "name": c.name,
                "total_spots": c.total_spots,
                "filled_spots": c.filled_spots,
                "available_spots": c.total_spots - c.filled_spots,
                "min_bid_cents": c.min_bid_cents,
            }
            for c in (e.sponsorship_categories or [])
            if not c.is_template and c.filled_spots < c.total_spots
        ]
        results.append({"event": e, "categories_summary": cats})
    return results


async def get_organizer_sponsors(
    db: AsyncSession, organizer_id: int, *, event_status: str | None = None,
    genre: str | None = None, event_id: int | None = None,
    offset: int = 0, limit: int = 20,
) -> list[dict]:
    """Distinct sponsors with active bids on any of this organizer's events."""
    rows = await sponsor_repo.get_organizer_sponsor_rows(
        db, organizer_id,
        event_status=event_status, genre=genre, event_id=event_id,
        offset=offset, limit=limit,
    )
    if not rows:
        return []

    user_ids = [r.sponsor_user_id for r in rows]
    profiles = await sponsor_repo.get_sponsor_profiles_by_user_ids(db, user_ids)
    users = await sponsor_repo.get_users_by_ids(db, user_ids)

    result = []
    for r in rows:
        uid = r.sponsor_user_id
        profile = profiles.get(uid)
        user = users.get(uid)

        if profile:
            name = profile.company_name
            contact = profile.contact_name
            logo = profile.logo_url
        else:
            name = user.display_name if user else "Unknown"
            contact = user.display_name or "" if user else ""
            logo = None

        result.append({
            "sponsor_user_id": uid,
            "company_name": name,
            "contact_name": contact,
            "logo_url": logo,
            "total_bids": r.total_bids,
            "total_amount_cents": r.total_amount_cents or 0,
        })
    return result


async def get_sponsor_events_for_organizer(
    db: AsyncSession, organizer_id: int, sponsor_user_id: int
) -> list[dict]:
    """Events where a specific sponsor has active bids, for this organizer."""
    active = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]

    events = await sponsor_repo.get_sponsor_events_for_organizer_events(
        db, organizer_id, sponsor_user_id
    )
    if not events:
        return []

    event_ids = [e.id for e in events]
    all_bids = await sponsor_repo.get_sponsor_bids_for_events(db, event_ids, sponsor_user_id)

    summary_by_event: dict[int, dict] = {}
    bids_by_event: dict[int, list] = {}
    for r in all_bids:
        eid = r.event_id
        status_val = r.status.value if hasattr(r.status, "value") else str(r.status)
        if eid not in summary_by_event:
            summary_by_event[eid] = {"pending": 0, "accepted": 0, "rejected": 0, "paid": 0, "withdrawn": 0}
        if status_val in summary_by_event[eid]:
            summary_by_event[eid][status_val] += 1
        if r.status in active:
            bids_by_event.setdefault(eid, []).append(
                {"category": r.name, "amount_cents": r.amount_cents, "status": status_val}
            )

    result = []
    for e in events:
        bids_detail = bids_by_event.get(e.id, [])
        total_cents = sum(b["amount_cents"] for b in bids_detail)
        venue = e.venue
        result.append({
            "event_id": e.id,
            "title": e.title,
            "status": e.status.value,
            "start_time": e.start_time.isoformat() if e.start_time else None,
            "venue_name": venue.name if venue else None,
            "venue_city": venue.city if venue else None,
            "bid_summary": summary_by_event.get(e.id, {"pending": 0, "accepted": 0, "rejected": 0, "paid": 0, "withdrawn": 0}),
            "bids": bids_detail,
            "total_amount_cents": total_cents,
        })
    return result


async def get_paid_sponsors(db: AsyncSession, event_id: int) -> list[dict]:
    """Return company_name + logo_url for sponsors with paid bids on this event."""
    rows = await sponsor_repo.get_paid_sponsors(db, event_id)
    return [
        {
            "sponsor_user_id": r.sponsor_user_id,
            "company_name": r.company_name,
            "logo_url": r.logo_url,
            "website_url": r.website_url,
        }
        for r in rows
    ]
