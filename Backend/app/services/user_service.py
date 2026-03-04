"""
User service: business logic for user profile, receipts, and bookmarks.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.repositories.event_repo import event_repo
from app.repositories.funding_repo import funding_repo
from app.repositories.user_repo import user_repo
from app.services import event as event_service
from app.services import platform_settings as settings_svc


async def get_pledge_receipt(
    db: AsyncSession,
    pledge_id: int,
    user_id: int,
    user_display_name: str | None,
):
    """Load pledge + event + tier data and return receipt dict."""
    pledge = await funding_repo.get_funding_by_id(db, pledge_id)
    if not pledge or pledge.user_id != user_id:
        raise NotFoundError("Pledge", pledge_id)
    event = await event_service.get_or_404(db, pledge.event_id)
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")
    tier_resp = await event_repo.build_tier_reservation_response(db, pledge.id)
    return {
        "pledge": pledge,
        "event": event,
        "funding_commission_percent": funding_pct,
        "tier_reservations": tier_resp,
        "backer_name": user_display_name,
    }


async def get_ticket_receipt(
    db: AsyncSession,
    sale,
):
    """Load venue + organizer info for a ticket receipt. Returns enrichment dict."""
    venue_name = None
    venue_address = None
    if sale.event and sale.event.venue_id:
        venue = await event_repo.get_venue(db, sale.event.venue_id)
        if venue:
            venue_name = venue.name
            parts = [p for p in [venue.address, venue.city, venue.province] if p]
            venue_address = ", ".join(parts) if parts else None

    organizer_name = None
    organizer_email = None
    organizer_phone = None
    if sale.event and sale.event.organizer_id:
        organizer = await user_repo.get_by_id(db, sale.event.organizer_id)
        if organizer:
            organizer_name = organizer.display_name
            organizer_email = organizer.email
            organizer_phone = organizer.phone

    return {
        "venue_name": venue_name,
        "venue_address": venue_address,
        "organizer_name": organizer_name,
        "organizer_email": organizer_email,
        "organizer_phone": organizer_phone,
    }


async def toggle_bookmark(
    db: AsyncSession,
    user_id: int,
    event_id: int,
) -> bool:
    """Toggle bookmark on an event. Returns True if now bookmarked, False if removed."""
    from app.models.bookmark import Bookmark

    existing = await event_repo.get_bookmark(db, user_id, event_id)
    if existing:
        await event_repo.delete_bookmark(db, existing)
        return False

    await event_service.get_or_404(db, event_id)
    await event_repo.create_bookmark(db, Bookmark(user_id=user_id, event_id=event_id))
    return True
