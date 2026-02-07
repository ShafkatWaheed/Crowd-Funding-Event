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
    start = e.start_time.isoformat() if e.start_time.tzinfo else e.start_time.replace(tzinfo=timezone.utc).isoformat()
    end = e.end_time.isoformat() if e.end_time.tzinfo else e.end_time.replace(tzinfo=timezone.utc).isoformat()
    now = datetime.now(timezone.utc)
    is_live = e.start_time <= now <= e.end_time and e.status.value in ("approved", "live")
    return MapEventMarker(
        id=e.id,
        title=e.title,
        lat=e.lat or 0.0,
        lng=e.lng or 0.0,
        start_time=start,
        end_time=end,
        status=e.status.value,
        is_live=is_live,
    )


@router.get("/map", response_model=list[MapEventMarker])
async def map_events(
    db: DbSession,
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    radius_km: float | None = Query(None),
    city: str | None = Query(None, description="e.g. Ottawa"),
    live: bool | None = Query(None, description="Only events currently live"),
):
    """Events for map view: by bbox/radius or city. Optionally filter by live."""
    events = await event_service.list_events_for_map(
        db, city=city, live=live, lat=lat, lng=lng, radius_km=radius_km
    )
    return [_event_to_marker(e) for e in events if e.lat is not None and e.lng is not None]
