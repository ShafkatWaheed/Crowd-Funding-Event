"""
Sponsor marketplace API endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import DbSession, CurrentUser, CurrentUserOptional, require_feature
from app.models.user import UserRole
from app.schemas.sponsor import (
    SponsorProfileCreate,
    SponsorProfileUpdate,
    SponsorProfileResponse,
    CategoryCreate,
    CategoryUpdate,
    CategoryResponse,
    BidCreate,
    BidUpdate,
    BidResponse,
    PaymentResponse,
    SponsorTicketResponse,
)
from app.services import sponsor as sponsor_svc

router = APIRouter()

_feature_guard = require_feature("feature_sponsors_enabled")


# ── Sponsor Profile ──

@router.post(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def create_sponsor_profile(
    data: SponsorProfileCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    profile = await sponsor_svc.create_profile(db, current_user, data)
    await db.commit()
    await db.refresh(profile)
    return profile


@router.get(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
    dependencies=[Depends(_feature_guard)],
)
async def get_sponsor_profile(db: DbSession, current_user: CurrentUser):
    profile = await sponsor_svc.get_profile(db, current_user.id)
    if not profile:
        raise HTTPException(status_code=404, detail="Sponsor profile not found")
    return profile


@router.patch(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
    dependencies=[Depends(_feature_guard)],
)
async def update_sponsor_profile(
    data: SponsorProfileUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    profile = await sponsor_svc.update_profile(db, current_user.id, data)
    await db.commit()
    await db.refresh(profile)
    return profile


# ── Sponsorship Categories ──

def _category_to_response(cat, bid_count: int = 0, bid_amounts: list[int] | None = None) -> dict:
    return {
        "id": cat.id,
        "event_id": cat.event_id,
        "name": cat.name,
        "description": cat.description,
        "image_url": cat.image_url,
        "total_spots": cat.total_spots,
        "filled_spots": cat.filled_spots,
        "min_bid_cents": cat.min_bid_cents,
        "sort_order": cat.sort_order,
        "bid_count": bid_count,
        "bid_amounts": bid_amounts or [],
    }


@router.get(
    "/events/{event_id}/sponsorships",
    response_model=list[CategoryResponse],
    dependencies=[Depends(_feature_guard)],
)
async def list_categories(
    event_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    if current_user.role not in (UserRole.sponsor, UserRole.organizer, UserRole.admin):
        raise HTTPException(status_code=403, detail="Sponsorship categories are not visible to customers")
    cats = await sponsor_svc.list_categories(db, event_id)
    result = []
    for c in cats:
        count, amounts = await sponsor_svc.get_bid_stats(db, c.id)
        result.append(_category_to_response(c, bid_count=count, bid_amounts=amounts))
    return result


@router.post(
    "/events/{event_id}/sponsorships",
    response_model=CategoryResponse,
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def create_category(
    event_id: int,
    data: CategoryCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.create_category(db, event_id, current_user, data)
    await db.commit()
    await db.refresh(cat)
    return _category_to_response(cat)


@router.patch(
    "/events/{event_id}/sponsorships/{cat_id}",
    response_model=CategoryResponse,
    dependencies=[Depends(_feature_guard)],
)
async def update_category(
    event_id: int,
    cat_id: int,
    data: CategoryUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.update_category(db, cat_id, current_user, data)
    await db.commit()
    await db.refresh(cat)
    return _category_to_response(cat)


@router.delete(
    "/events/{event_id}/sponsorships/{cat_id}",
    status_code=204,
    dependencies=[Depends(_feature_guard)],
)
async def delete_category(
    event_id: int,
    cat_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    await sponsor_svc.delete_category(db, cat_id, current_user)
    await db.commit()


# ── Bids ──

async def _bid_to_response(db, bid) -> dict:
    profile = await sponsor_svc.get_profile(db, bid.sponsor_user_id)
    profile_data = None
    if profile:
        profile_data = {
            "id": profile.id,
            "user_id": profile.user_id,
            "company_name": profile.company_name,
            "contact_name": profile.contact_name,
            "profession": profile.profession,
            "logo_url": profile.logo_url,
            "description": profile.description,
            "website_url": profile.website_url,
        }
    return {
        "id": bid.id,
        "category_id": bid.category_id,
        "sponsor_user_id": bid.sponsor_user_id,
        "amount_cents": bid.amount_cents,
        "proposal_text": bid.proposal_text,
        "status": bid.status.value,
        "sponsor_profile": profile_data,
    }


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids",
    response_model=BidResponse,
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def place_bid(
    event_id: int,
    cat_id: int,
    data: BidCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.place_bid(db, cat_id, current_user, data)
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


@router.patch(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}",
    response_model=BidResponse,
    dependencies=[Depends(_feature_guard)],
)
async def update_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    data: BidUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.update_bid(db, bid_id, current_user, data)
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/withdraw",
    response_model=BidResponse,
    dependencies=[Depends(_feature_guard)],
)
async def withdraw_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.withdraw_bid(db, bid_id, current_user)
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


@router.get(
    "/events/{event_id}/sponsorships/{cat_id}/bids",
    response_model=list[BidResponse],
    dependencies=[Depends(_feature_guard)],
)
async def list_bids(
    event_id: int,
    cat_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    bids = await sponsor_svc.list_bids(db, cat_id, current_user)
    return [await _bid_to_response(db, b) for b in bids]


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/accept",
    response_model=BidResponse,
    dependencies=[Depends(_feature_guard)],
)
async def accept_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.accept_bid(db, bid_id, current_user)
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/reject",
    response_model=BidResponse,
    dependencies=[Depends(_feature_guard)],
)
async def reject_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.reject_bid(db, bid_id, current_user)
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


# ── Payments ──

@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/pay",
    response_model=PaymentResponse,
    dependencies=[Depends(_feature_guard)],
)
async def pay_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    payment = await sponsor_svc.pay_bid(db, bid_id, current_user)
    await db.commit()
    await db.refresh(payment)
    return payment


# ── Sponsor Tickets ──

@router.get(
    "/me/sponsor-tickets",
    response_model=list[SponsorTicketResponse],
    dependencies=[Depends(_feature_guard)],
)
async def list_my_sponsor_tickets(db: DbSession, current_user: CurrentUser):
    tickets = await sponsor_svc.list_sponsor_tickets(db, current_user.id)
    result = []
    for t in tickets:
        cats = await sponsor_svc.get_won_categories(db, t.event_id, current_user.id)
        result.append({
            "id": t.id,
            "event_id": t.event_id,
            "sponsor_user_id": t.sponsor_user_id,
            "receipt_number": t.receipt_number,
            "encrypted_qr_payload": t.qr_data_encrypted,
            "scanned_at": t.scanned_at.isoformat() if t.scanned_at else None,
            "category_names": cats,
            "category_count": len(cats),
        })
    return result


@router.post(
    "/events/{event_id}/scan-sponsor",
    dependencies=[Depends(_feature_guard)],
)
async def scan_sponsor_ticket(
    event_id: int,
    body: dict,
    db: DbSession,
    current_user: CurrentUser,
):
    payload = body.get("encrypted_payload", "")
    if not payload:
        raise HTTPException(status_code=400, detail="encrypted_payload required")
    result = await sponsor_svc.scan_sponsor_ticket(db, event_id, payload)
    await db.commit()
    return result


# ── Public Sponsor Carousel ──

@router.get(
    "/events/{event_id}/sponsors",
    dependencies=[Depends(_feature_guard)],
)
async def list_event_sponsors(event_id: int, db: DbSession):
    """Public endpoint: returns approved sponsor logos for the carousel."""
    sponsors = await sponsor_svc.get_paid_sponsors(db, event_id)
    return sponsors
