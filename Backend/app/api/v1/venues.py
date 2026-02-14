"""
Venues: each organizer owns their venues; customers see all. Organizers cannot see others' venues.
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func

from app.dependencies import DbSession, require_role, CurrentUserOptional
from app.models.event import Event
from app.models.user import User, UserRole
from app.schemas import VenueCreate, VenueResponse, VenueUpdate
from app.services import venue as venue_service
from app.core.exceptions import ConflictError, ForbiddenError

router = APIRouter()


@router.get("", response_model=list[VenueResponse])
async def list_venues(
    db: DbSession,
    current_user: CurrentUserOptional,
    city: str | None = Query(None, description="e.g. Ottawa"),
):
    """List venues: customers (or no auth) see all; organizers see only their own."""
    organizer_id = current_user.id if (current_user and current_user.role == UserRole.organizer) else None
    venues = await venue_service.list_venues(db, city=city, organizer_id=organizer_id)
    return venues


@router.post("", response_model=VenueResponse)
async def create_venue(
    body: VenueCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create venue (organizer or admin). Venue is owned by the current user."""
    venue = await venue_service.create(
        db,
        organizer_id=current_user.id,
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
async def get_venue(
    venue_id: int,
    db: DbSession,
    current_user: CurrentUserOptional,
):
    """Venue detail. Customers can see any; organizers can see only their own."""
    venue = await venue_service.get_or_404(db, venue_id)
    if current_user and current_user.role == UserRole.organizer and venue.organizer_id != current_user.id:
        raise ForbiddenError("You cannot view another organizer's venue")
    return venue


@router.patch("/{venue_id}", response_model=VenueResponse)
async def update_venue(
    venue_id: int,
    body: VenueUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update venue. Only the owner or admin."""
    venue = await venue_service.get_or_404(db, venue_id)
    if not venue_service.can_edit_venue(current_user.id, venue, current_user.role == UserRole.admin):
        raise ForbiddenError("You cannot update another organizer's venue")
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


@router.delete("/{venue_id}")
async def delete_venue(
    venue_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete venue. Only the owner or admin."""
    venue = await venue_service.get_or_404(db, venue_id)
    if not venue_service.can_edit_venue(current_user.id, venue, current_user.role == UserRole.admin):
        raise ForbiddenError("You cannot delete another organizer's venue")

    # Prevent deletion if events are linked to this venue
    event_count_result = await db.execute(
        select(func.count()).select_from(Event).where(Event.venue_id == venue_id)
    )
    event_count = event_count_result.scalar() or 0
    if event_count > 0:
        raise ConflictError(
            f"Cannot delete venue: {event_count} event(s) are still linked to it. "
            "Reassign or delete those events first."
        )

    await db.delete(venue)
    await db.flush()
    return {"ok": True}
