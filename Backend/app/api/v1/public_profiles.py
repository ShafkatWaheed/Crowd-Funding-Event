"""
Public user profiles: display_name, trust score, public events.
No email or phone exposed.
"""
from fastapi import APIRouter, Query

from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.dependencies import CurrentUser, DbSession
from app.models.user import User
from app.models.event import Event, EventStatus

router = APIRouter()


@router.get("/{user_id}/public-profile")
async def get_public_profile(
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Public profile for any user. No email/phone."""
    user = (await db.execute(
        select(User).where(User.id == user_id)
    )).scalar_one_or_none()
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
    return profile


@router.get("/{user_id}/sponsor-public-profile")
async def get_sponsor_public_profile(
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Public sponsor profile with bid statistics. No email/phone."""
    from app.core.exceptions import NotFoundError
    from app.models.sponsor import SponsorProfile, SponsorBid, BidStatus, SponsorshipCategory

    user = (await db.execute(
        select(User).where(User.id == user_id)
    )).scalar_one_or_none()
    if not user:
        raise NotFoundError("User", user_id)

    profile = (await db.execute(
        select(SponsorProfile).where(SponsorProfile.user_id == user_id)
    )).scalar_one_or_none()

    total_bids = (await db.execute(
        select(func.count()).select_from(SponsorBid).where(SponsorBid.sponsor_user_id == user_id)
    )).scalar_one()

    accepted_bids = (await db.execute(
        select(func.count()).select_from(SponsorBid).where(
            SponsorBid.sponsor_user_id == user_id,
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid]),
        )
    )).scalar_one()

    events_sponsored = (await db.execute(
        select(func.count(func.distinct(SponsorshipCategory.event_id)))
        .select_from(SponsorBid)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorBid.sponsor_user_id == user_id,
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid]),
        )
    )).scalar_one()

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
    }


@router.get("/{user_id}/public-events")
async def get_public_events(
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List public (non-draft) events organized by this user."""
    visible_statuses = [
        EventStatus.approved,
        EventStatus.selling_tickets,
        EventStatus.waiting_event_date,
        EventStatus.live,
        EventStatus.completed,
    ]
    events = (await db.execute(
        select(Event)
        .where(Event.organizer_id == user_id, Event.status.in_(visible_statuses))
        .options(selectinload(Event.venue), selectinload(Event.organizer), selectinload(Event.ticket_strategy))
        .order_by(Event.created_at.desc())
        .offset(offset)
        .limit(limit)
    )).scalars().unique().all()

    from app.api.v1.events import _event_to_response
    return [_event_to_response(e) for e in events]
