"""
Public user profiles: display_name, trust score, public events.
No email or phone exposed.
"""
from fastapi import APIRouter, Query

from app.dependencies import CurrentUser, ReadDbSession
from app.repositories.user_repo import user_repo
from app.repositories.event_repo import event_repo
from app.repositories.sponsor_repo import sponsor_repo

router = APIRouter()


@router.get("/{user_id}/public-profile")
async def get_public_profile(
    user_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    """Public profile for any user. No email/phone."""
    user = await user_repo.get_by_id(db, user_id)
    if not user:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("User", user_id)

    from app.services import event as event_service
    trust = await event_service.get_organizer_trust_score(db, organizer_id=user_id)

    profile = {
        "id": user.id,
        "display_name": user.display_name,
        "role": user.role.value,
        "address": user.address,
        "years_of_experience": user.years_of_experience,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "trust": trust,
        # Contact & social presence
        "bio": user.bio,
        "website_url": user.website_url,
        "contact_email": user.contact_email,
        "instagram": user.instagram,
        "twitter": user.twitter,
        "facebook": user.facebook,
        "linkedin": user.linkedin,
        "youtube": user.youtube,
        "tiktok": user.tiktok,
    }

    sponsor_profile = None
    try:
        from app.services import sponsor as sponsor_svc
        sp = await sponsor_svc.get_profile(db, user_id)
        if sp:
            sponsor_profile = {
                "id": sp.id,
                "company_name": sp.company_name,
                "contact_name": sp.contact_name,
                "profession": sp.profession,
                "logo_url": sp.logo_url,
                "description": sp.description,
                "website_url": sp.website_url,
            }
    except Exception:
        pass

    profile["sponsor_profile"] = sponsor_profile

    event_metrics = await event_repo.get_organizer_event_metrics(db, user_id)
    profile["event_metrics"] = event_metrics

    return profile


@router.get("/{user_id}/sponsor-public-profile")
async def get_sponsor_public_profile(
    user_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    """Public sponsor profile with bid statistics. No email/phone."""
    from app.core.exceptions import NotFoundError

    user = await user_repo.get_by_id(db, user_id)
    if not user:
        raise NotFoundError("User", user_id)

    profile = await sponsor_repo.get_sponsor_profile(db, user_id)
    total_bids, accepted_bids, events_sponsored = await sponsor_repo.get_sponsor_bid_counts(db, user_id)

    return {
        "id": user_id,
        "display_name": user.display_name,
        "company_name": profile.company_name if profile else None,
        "contact_name": profile.contact_name if profile else None,
        "profession": profile.profession if profile else None,
        "logo_url": profile.logo_url if profile else None,
        "description": profile.description if profile else None,
        "website_url": profile.website_url if profile else None,
        "member_since": user.created_at.isoformat() if user.created_at else None,
        "total_bids": total_bids,
        "accepted_bids": accepted_bids,
        "events_sponsored": events_sponsored,
        # Contact & social presence
        "bio": user.bio,
        "contact_email": user.contact_email,
        "instagram": user.instagram,
        "twitter": user.twitter,
        "facebook": user.facebook,
        "linkedin": user.linkedin,
        "youtube": user.youtube,
        "tiktok": user.tiktok,
    }


@router.get("/{user_id}/public-events")
async def get_public_events(
    user_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None),
    status: str | None = Query(None),
):
    """List public (non-draft) events organized by this user."""
    events = await event_repo.list_public_events_for_user(
        db, user_id, offset=offset, limit=limit, search=search, status=status,
    )

    from app.api.v1.events import _event_to_response
    return [_event_to_response(e) for e in events]
