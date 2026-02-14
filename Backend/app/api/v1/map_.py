"""
Map: events in bounding box or by city (Ottawa), live filter.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Query

from app.dependencies import DbSession
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
async def map_events(
    db: DbSession,
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    radius_km: float | None = Query(None),
    city: str | None = Query(None, description="e.g. Ottawa"),
    live: bool | None = Query(None, description="Only events currently live"),
    organizer_id: int | None = Query(None, description="Filter to a specific organizer's events"),
):
    """Events for map view: by bbox/radius or city. Optionally filter by live or organizer."""
    events = await event_service.list_events_for_map(
        db, city=city, live=live, lat=lat, lng=lng, radius_km=radius_km,
        organizer_id=organizer_id,
    )
    return [_event_to_marker(e) for e in events if e.lat is not None and e.lng is not None]
