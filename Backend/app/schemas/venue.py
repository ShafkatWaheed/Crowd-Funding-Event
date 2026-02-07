# Venue request/response schemas.
from pydantic import BaseModel


class VenueCreate(BaseModel):
    name: str
    address: str
    city: str
    province: str | None = None
    lat: float | None = None
    lng: float | None = None
    max_capacity: int


class VenueUpdate(BaseModel):
    name: str | None = None
    address: str | None = None
    city: str | None = None
    province: str | None = None
    lat: float | None = None
    lng: float | None = None
    max_capacity: int | None = None


class VenueResponse(BaseModel):
    id: int
    name: str
    address: str
    city: str
    province: str | None
    lat: float | None
    lng: float | None
    max_capacity: int

    model_config = {"from_attributes": True}
