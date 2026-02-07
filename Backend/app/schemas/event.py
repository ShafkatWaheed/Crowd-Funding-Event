# Event request/response schemas.
from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class EventCreate(BaseModel):
    venue_id: int
    title: str
    description: str | None = None
    start_time: str  # ISO datetime
    end_time: str
    funding_goal_cents: int | None = None
    funding_end_at: str | None = None
    registration_type: Literal["open", "closed"] = "open"
    max_capacity: int


class EventUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    funding_goal_cents: int | None = None
    funding_end_at: str | None = None
    registration_type: Literal["open", "closed"] | None = None
    max_capacity: int | None = None


class EventResponse(BaseModel):
    id: int
    organizer_id: int
    venue_id: int
    title: str
    description: str | None
    start_time: datetime
    end_time: datetime
    status: str
    registration_type: str
    max_capacity: int
    funding_goal_cents: int | None
    funding_end_at: datetime | None
    lat: float | None
    lng: float | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MapEventMarker(BaseModel):
    """Event marker for map view (lat/lng, times, live flag)."""
    id: int
    title: str
    lat: float
    lng: float
    start_time: str
    end_time: str
    status: str
    is_live: bool
