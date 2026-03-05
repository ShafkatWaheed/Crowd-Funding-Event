"""
Venues: each organizer owns their venues; customers see all. Organizers cannot see others' venues.
"""
from fastapi import APIRouter, Depends, Query

from app.dependencies import DbSession, ReadDbSession, require_role, CurrentUserOptional
from app.models.user import User, UserRole
from app.schemas import VenueCreate, VenueResponse, VenueUpdate
from app.services import venue as venue_service
from app.repositories.venue_repo import venue_repo
from app.core.exceptions import ConflictError, ForbiddenError

router = APIRouter()


@router.get("", response_model=list[VenueResponse])
async def list_venues(
    db: ReadDbSession,
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
    db: ReadDbSession,
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

    # Block deletion only if active (non-terminal) events still reference this venue
    active_count = await venue_repo.count_active_events_for_venue(db, venue_id)
    if active_count > 0:
        raise ConflictError(
            f"Cannot delete venue: {active_count} active event(s) are still linked to it. "
            "Reassign or delete those events first."
        )

    # Snapshot venue data on completed/cancelled events, then unlink them
    await venue_service.prepare_venue_deletion(db, venue_id)

    await venue_repo.delete_venue(db, venue)
    return {"ok": True}
