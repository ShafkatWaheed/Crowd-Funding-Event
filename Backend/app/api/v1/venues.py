"""
Venues: CRUD for halls/venues (capacity, location).
"""
from fastapi import APIRouter, Depends, Query

from app.dependencies import CurrentUser, DbSession, require_role
from app.models.user import UserRole
from app.schemas import VenueCreate, VenueResponse, VenueUpdate
from app.services import venue as venue_service

router = APIRouter()


@router.get("", response_model=list[VenueResponse])
async def list_venues(
    db: DbSession,
    city: str | None = Query(None, description="e.g. Ottawa"),
):
    """List venues, optionally by city."""
    venues = await venue_service.list_venues(db, city=city)
    return venues


@router.post("", response_model=VenueResponse)
async def create_venue(
    body: VenueCreate,
    db: DbSession,
    current_user: CurrentUser = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create venue (organizer or admin)."""
    venue = await venue_service.create(
        db,
        name=body.name,
        address=body.address,
        city=body.city,
        province=body.province,
        lat=body.lat,
        lng=body.lng,
        max_capacity=body.max_capacity,
    )
    return venue


@router.get("/{venue_id}", response_model=VenueResponse)
async def get_venue(venue_id: int, db: DbSession):
    """Venue detail."""
    venue = await venue_service.get_or_404(db, venue_id)
    return venue


@router.patch("/{venue_id}", response_model=VenueResponse)
async def update_venue(
    venue_id: int,
    body: VenueUpdate,
    db: DbSession,
    current_user: CurrentUser = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update venue."""
    venue = await venue_service.get_or_404(db, venue_id)
    updated = await venue_service.update(
        db,
        venue,
        name=body.name,
        address=body.address,
        city=body.city,
        province=body.province,
        lat=body.lat,
        lng=body.lng,
        max_capacity=body.max_capacity,
    )
    return updated
