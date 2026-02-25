"""
Shared helpers for events API: parsing, response builders, batch image fetch.
"""
from datetime import date, datetime, timezone
from urllib.parse import quote_plus

from sqlalchemy import func, inspect as sa_inspect, select

from app.models.event import Event
from app.models.funding import PledgeSpotReservation
from app.models.image import EventImage
from app.models.ticket import TicketTier
from app.schemas import EventResponse, EventVenueInfo, OrganizerTrustInfo


def _parse_iso_datetime(v: str | None) -> datetime | None:
    if v is None:
        return None
    dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _directions_url(e: Event) -> str | None:
    """Build a Google Maps directions link from the venue address or event lat/lng."""
    if e.venue:
        parts = [e.venue.address, e.venue.city]
        if e.venue.province:
            parts.append(e.venue.province)
        addr = ", ".join(parts)
        return f"https://www.google.com/maps/dir/?api=1&destination={quote_plus(addr)}"
    if e.lat is not None and e.lng is not None:
        return f"https://www.google.com/maps/dir/?api=1&destination={e.lat},{e.lng}"
    return None


async def _get_first_images(db, event_ids: list[int]) -> dict[int, str]:
    """Batch-fetch the first image URL for each event (by display_order)."""
    if not event_ids:
        return {}
    subq = (
        select(
            EventImage.event_id,
            func.min(EventImage.id).label("min_id"),
        )
        .where(EventImage.event_id.in_(event_ids))
        .group_by(EventImage.event_id)
        .subquery()
    )
    rows = (
        await db.execute(
            select(EventImage.event_id, EventImage.image_url)
            .join(subq, EventImage.id == subq.c.min_id)
        )
    ).all()
    return {r.event_id: r.image_url for r in rows}


async def _build_tier_reservation_response(db, funding_id: int) -> list[dict]:
    """Build tier reservation list for a pledge response."""
    rows = list((await db.execute(
        select(PledgeSpotReservation).where(PledgeSpotReservation.funding_id == funding_id)
    )).scalars().all())
    if not rows:
        return []
    result = []
    for r in rows:
        tier = (await db.execute(select(TicketTier).where(TicketTier.id == r.ticket_tier_id))).scalar_one_or_none()
        result.append({
            "tier_id": r.ticket_tier_id,
            "tier_name": tier.name if tier else None,
            "spots": r.spots,
        })
    return result


def _event_to_response(
    e: Event,
    *,
    total_pledged_cents: int | None = None,
    funding_days_left: int | None = None,
    total_reserved_spots: int = 0,
    tickets_sold_count: int = 0,
    include_dislike: bool = False,
    organizer_trust: dict | None = None,
    first_image_url: str | None = None,
) -> EventResponse:
    """Build response; e.venue must be loaded so everyone can see venue info when viewing an event."""
    venue_info = EventVenueInfo.model_validate(e.venue) if e.venue else None
    if venue_info is None:
        raise ValueError("Event.venue must be loaded when building EventResponse")
    trust_info = None
    if organizer_trust:
        trust_info = OrganizerTrustInfo(
            trust_score=organizer_trust["trust_score"],
            label=organizer_trust["label"],
            completed_events=organizer_trust["completed_events"],
            published_events=organizer_trust["published_events"],
        )
    org_name = None
    state = sa_inspect(e)
    if "organizer" in state.dict and e.organizer:
        org_name = e.organizer.display_name
    return EventResponse(
        id=e.id,
        organizer_id=e.organizer_id,
        organizer_name=org_name,
        venue_id=e.venue_id,
        venue=venue_info,
        title=e.title,
        description=e.description,
        start_time=e.start_time,
        end_time=e.end_time,
        status=e.status.value,
        registration_type=e.registration_type.value,
        max_capacity=e.max_capacity,
        max_reserved_spots_per_user=e.max_reserved_spots_per_user,
        funding_goal_cents=e.funding_goal_cents,
        funding_end_at=e.funding_end_at,
        total_pledged_cents=total_pledged_cents,
        funding_days_left=funding_days_left,
        total_reserved_spots=total_reserved_spots,
        tickets_sold_count=tickets_sold_count,
        min_pledge_cents=e.min_pledge_cents,
        common_discount_percent=e.common_discount_percent,
        pledge_discount_percent=e.pledge_discount_percent,
        cancellation_reason=e.cancellation_reason,
        registration_count=e.registration_count,
        genre=e.genre,
        community_rules=e.community_rules,
        posts_enabled=e.posts_enabled,
        refund_deadline_days=e.refund_deadline_days,
        event_date_deadline=e.event_date_deadline,
        ticket_strategy_id=e.ticket_strategy_id,
        ticket_strategy_name=e.ticket_strategy.name if e.ticket_strategy_id and e.ticket_strategy else None,
        like_count=e.like_count,
        dislike_count=e.dislike_count if include_dislike else 0,
        pending_extension=e.pending_extension,
        pending_cancellation=e.pending_cancellation,
        organizer_trust=trust_info,
        parking_info=e.parking_info,
        transit_info=e.transit_info,
        rideshare_info=e.rideshare_info,
        accessibility_info=e.accessibility_info,
        has_schedule=e.has_schedule,
        link_funding_to_tiers=e.link_funding_to_tiers,
        max_discount_percent=getattr(e, "max_discount_percent", 100),
        directions_url=_directions_url(e),
        first_image_url=first_image_url,
        lat=e.lat,
        lng=e.lng,
        created_at=e.created_at,
        updated_at=e.updated_at,
    )


def _parse_date_or_datetime(v: str | None, end_of_day: bool = False) -> datetime | None:
    """Parse ISO date (YYYY-MM-DD) or datetime; return as UTC. If date only: start of day or end of day."""
    if v is None:
        return None
    v = v.strip()
    if not v:
        return None
    try:
        if "T" in v or " " in v or (len(v) >= 19 and v[10:11] in ("T", " ")):
            dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
        else:
            d = date.fromisoformat(v)
            if end_of_day:
                dt = datetime.combine(d, datetime.max.time()).replace(tzinfo=timezone.utc)
            else:
                dt = datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except (ValueError, TypeError):
        return None


def _event_to_ics(event: Event) -> str:
    """Build iCalendar (.ics) string for the event. Event.venue must be loaded for location."""
    def ical_dt(dt: datetime) -> str:
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y%m%dT%H%M%SZ")

    now = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    uid = f"event-{event.id}@crowdfund"
    summary = (event.title or "Event").replace("\r", "").replace("\n", " ")
    description = (event.description or "").replace("\r", " ").replace("\n", " ")
    location = ""
    if event.venue:
        parts = [event.venue.name, event.venue.address, event.venue.city]
        if event.venue.province:
            parts.append(event.venue.province)
        location = ", ".join(p for p in parts if p).replace("\r", " ").replace("\n", " ")
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//CrowdFund Event//EN",
        "CALSCALE:GREGORIAN",
        "BEGIN:VEVENT",
        f"UID:{uid}",
        f"DTSTAMP:{now}",
        f"DTSTART:{ical_dt(event.start_time)}",
        f"DTEND:{ical_dt(event.end_time)}",
        f"SUMMARY:{summary}",
        f"DESCRIPTION:{description}",
        f"LOCATION:{location}",
        "END:VEVENT",
        "END:VCALENDAR",
    ]
    return "\r\n".join(lines)
