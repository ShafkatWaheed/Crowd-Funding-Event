"""
Map: events in bounding box or by city (Ottawa), live filter.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Query, Request

from app.dependencies import ReadDbSession
from app.rate_limit import limiter, dynamic_limit
from app.models.event import Event
from app.schemas import MapEventMarker
from app.services import event as event_service

router = APIRouter()


def _event_to_marker(e: Event) -> MapEventMarker:
    start = None
    end = None
    if e.start_time is not None:
        start = e.start_time.isoformat() if e.start_time.tzinfo else e.start_time.replace(tzinfo=timezone.utc).isoformat()
    if e.end_time is not None:
        end = e.end_time.isoformat() if e.end_time.tzinfo else e.end_time.replace(tzinfo=timezone.utc).isoformat()
    now = datetime.now(timezone.utc)
    is_live = (
        e.start_time is not None and e.end_time is not None
        and e.start_time <= now <= e.end_time
        and e.status.value in ("approved", "live", "selling_tickets")
    )
    return MapEventMarker(
        id=e.id,
        title=e.title,
        lat=e.lat or 0.0,
        lng=e.lng or 0.0,
        start_time=start,
        end_time=end,
        status=e.status.value,
        is_live=is_live,
        venue_id=e.venue_id if hasattr(e, "venue_id") else None,
        venue_name=e.venue.name if e.venue else None,
    )


@router.get("/map", response_model=list[MapEventMarker])
@limiter.limit(dynamic_limit("public_search", "60/minute"))
async def map_events(
    request: Request,
    db: ReadDbSession,
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    radius_km: float | None = Query(None),
    city: str | None = Query(None, description="e.g. Ottawa"),
    live: bool | None = Query(None, description="Only events currently live"),
    organizer_id: int | None = Query(None, description="Filter to a specific organizer's events"),
    search: str | None = Query(None, description="Search by event title"),
    genre: str | None = Query(None, description="Filter by genre"),
    status: str | None = Query(None, description="Filter by event status"),
    sponsorship_only: bool = Query(False, description="Only events with sponsorship categories"),
):
    """Events for map view: by bbox/radius or city. Optionally filter by live, organizer, search, genre, status, or sponsorship."""
    from app.cache import cache_get_or_compute, safe_cache_key
    from app.services.platform_settings import get_int as get_setting_int, get_float as get_setting_float

    # Only cache simple filter combos (city/genre/status); skip for geo/search/organizer queries
    use_cache = lat is None and lng is None and radius_km is None and search is None and organizer_id is None

    async def _compute():
        events = await event_service.list_events_for_map(
            db, city=city, live=live, lat=lat, lng=lng, radius_km=radius_km,
            organizer_id=organizer_id, search=search, genre=genre, status=status,
            sponsorship_only=sponsorship_only,
        )
        return [_event_to_marker(e).model_dump(mode="json") for e in events if e.lat is not None and e.lng is not None]

    if use_cache:
        cache_key = safe_cache_key("map", city or "", genre or "", status or "", str(live or ""), str(sponsorship_only))
        ttl = await get_setting_int(db, "cache_ttl_map")
        beta = await get_setting_float(db, "cache_beta_map")
        return await cache_get_or_compute(cache_key, _compute, ttl=ttl, beta=beta)

    return await _compute()
