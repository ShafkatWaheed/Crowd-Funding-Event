"""Organizer and public sponsor queries: bid events, sponsorship available, organizer sponsors, paid sponsors."""
from sqlalchemy import distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.user import User
from app.models.event import Event, EventStatus
from app.models.sponsor import SponsorBid, SponsorProfile, SponsorshipCategory, BidStatus

from app.services.sponsor.profile import get_profile


async def get_sponsor_bid_events(db: AsyncSession, sponsor_user_id: int) -> list[Event]:
    """Return distinct events where this sponsor has placed at least one active bid."""
    active_statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
    event_ids_q = (
        select(distinct(SponsorshipCategory.event_id))
        .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorBid.sponsor_user_id == sponsor_user_id,
            SponsorBid.status.in_(active_statuses),
        )
    )
    q = (
        select(Event)
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .where(Event.id.in_(event_ids_q))
        .order_by(Event.created_at.desc())
    )
    return list((await db.execute(q)).scalars().all())


async def get_sponsor_bid_summary_for_event(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> dict:
    """Return bid counts by status for a sponsor on a given event."""
    q = (
        select(SponsorBid.status, SponsorBid.id)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorBid.sponsor_user_id == sponsor_user_id,
        )
    )
    rows = (await db.execute(q)).all()
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
    open_cat_q = (
        select(distinct(SponsorshipCategory.event_id))
        .where(
            SponsorshipCategory.event_id.isnot(None),
            SponsorshipCategory.is_template == False,
            SponsorshipCategory.filled_spots < SponsorshipCategory.total_spots,
        )
    )

    if exclude_my_bids and sponsor_user_id:
        already_bid_event_ids = (
            select(distinct(SponsorshipCategory.event_id))
            .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorBid.sponsor_user_id == sponsor_user_id,
                SponsorBid.status.in_([BidStatus.pending, BidStatus.accepted, BidStatus.paid]),
            )
        )
        open_cat_q = open_cat_q.where(
            SponsorshipCategory.event_id.notin_(already_bid_event_ids)
        )

    q = (
        select(Event)
        .options(
            selectinload(Event.venue),
            selectinload(Event.ticket_strategy),
            selectinload(Event.sponsorship_categories),
        )
        .where(
            Event.id.in_(open_cat_q),
            Event.status.notin_(["cancelled", "completed"]),
        )
        .order_by(Event.created_at.desc())
    )
    events = list((await db.execute(q)).scalars().all())

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
    offset: int = 0, limit: int = 20,
) -> list[dict]:
    """Distinct sponsors with active bids on any of this organizer's events."""
    active = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]

    conditions = [
        Event.organizer_id == organizer_id,
        SponsorBid.status.in_(active),
    ]
    if event_status:
        try:
            conditions.append(Event.status == EventStatus(event_status))
        except ValueError:
            pass

    q = (
        select(
            SponsorBid.sponsor_user_id,
            func.count(SponsorBid.id).label("total_bids"),
            func.sum(SponsorBid.amount_cents).label("total_amount_cents"),
        )
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .join(Event, SponsorshipCategory.event_id == Event.id)
        .where(*conditions)
        .group_by(SponsorBid.sponsor_user_id)
        .order_by(func.sum(SponsorBid.amount_cents).desc())
        .offset(offset)
        .limit(limit)
    )
    rows = (await db.execute(q)).all()

    result = []
    for r in rows:
        uid = r.sponsor_user_id
        profile = await get_profile(db, uid)
        user = (await db.execute(
            select(User).where(User.id == uid)
        )).scalar_one_or_none()

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

    event_ids_q = (
        select(distinct(SponsorshipCategory.event_id))
        .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
        .join(Event, SponsorshipCategory.event_id == Event.id)
        .where(
            Event.organizer_id == organizer_id,
            SponsorBid.sponsor_user_id == sponsor_user_id,
            SponsorBid.status.in_(active),
        )
    )

    events = list((await db.execute(
        select(Event)
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .where(Event.id.in_(event_ids_q))
        .order_by(Event.created_at.desc())
    )).scalars().all())

    result = []
    for e in events:
        summary = await get_sponsor_bid_summary_for_event(db, e.id, sponsor_user_id)
        cats_q = (
            select(
                SponsorshipCategory.name,
                SponsorBid.amount_cents,
                SponsorBid.status,
            )
            .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorshipCategory.event_id == e.id,
                SponsorBid.sponsor_user_id == sponsor_user_id,
                SponsorBid.status.in_(active),
            )
        )
        cat_rows = (await db.execute(cats_q)).all()
        bids_detail = [
            {"category": r.name, "amount_cents": r.amount_cents, "status": r.status.value}
            for r in cat_rows
        ]
        total_cents = sum(b["amount_cents"] for b in bids_detail)
        venue = e.venue
        result.append({
            "event_id": e.id,
            "title": e.title,
            "status": e.status.value,
            "start_time": e.start_time.isoformat() if e.start_time else None,
            "venue_name": venue.name if venue else None,
            "venue_city": venue.city if venue else None,
            "bid_summary": summary,
            "bids": bids_detail,
            "total_amount_cents": total_cents,
        })
    return result


async def get_paid_sponsors(db: AsyncSession, event_id: int) -> list[dict]:
    """Return company_name + logo_url for sponsors with paid bids on this event."""
    q = (
        select(
            SponsorBid.sponsor_user_id,
            SponsorProfile.company_name,
            SponsorProfile.logo_url,
            SponsorProfile.website_url,
        )
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .join(SponsorProfile, SponsorBid.sponsor_user_id == SponsorProfile.user_id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorBid.status == BidStatus.paid,
        )
        .group_by(
            SponsorBid.sponsor_user_id,
            SponsorProfile.company_name,
            SponsorProfile.logo_url,
            SponsorProfile.website_url,
        )
    )
    rows = (await db.execute(q)).all()
    return [
        {
            "sponsor_user_id": r.sponsor_user_id,
            "company_name": r.company_name,
            "logo_url": r.logo_url,
            "website_url": r.website_url,
        }
        for r in rows
    ]
