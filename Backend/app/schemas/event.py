# Event request/response schemas.
from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class EventVenueInfo(BaseModel):
    """Venue info included with an event so everyone can see where it is (once venue is used in an event)."""
    id: int
    name: str
    address: str
    city: str
    province: str | None
    lat: float | None
    lng: float | None
    max_capacity: int

    model_config = {"from_attributes": True}


class EventCreate(BaseModel):
    venue_id: int
    title: str
    description: str | None = None
    start_time: str  # ISO datetime
    end_time: str
    funding_goal_cents: int | None = None
    funding_end_at: str | None = None
    min_pledge_cents: int  # required minimum pledge amount in cents
    registration_type: Literal["open", "closed"] = "open"
    max_capacity: int
    common_discount_percent: int = 0
    pledge_discount_percent: int = 0


class EventUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    funding_goal_cents: int | None = None
    funding_end_at: str | None = None
    min_pledge_cents: int | None = None
    registration_type: Literal["open", "closed"] | None = None
    max_capacity: int | None = None
    common_discount_percent: int | None = None
    pledge_discount_percent: int | None = None


class ExtendFundingBody(BaseModel):
    """After funding deadline: extend period and/or set event date. At least one required."""
    funding_end_at: str | None = None  # ISO datetime
    start_time: str | None = None  # event date
    end_time: str | None = None


class UnregisterResponse(BaseModel):
    refunded_cents: int
    pledges_refunded: int


class EventResponse(BaseModel):
    id: int
    organizer_id: int
    venue_id: int
    venue: EventVenueInfo
    title: str
    description: str | None
    start_time: datetime
    end_time: datetime
    status: str
    registration_type: str
    max_capacity: int
    funding_goal_cents: int | None
    funding_end_at: datetime | None
    min_pledge_cents: int
    common_discount_percent: int
    pledge_discount_percent: int
    lat: float | None
    lng: float | None
    created_at: datetime
    updated_at: datetime


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
