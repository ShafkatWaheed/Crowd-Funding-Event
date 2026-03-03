"""Sponsor bid endpoints."""
from fastapi import APIRouter, Depends

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature, require_kyc
from app.logger import get_logger, log_step
from app.schemas.sponsor import BidCreate, BidUpdate, BidResponse
from app.services import sponsor as sponsor_svc
from app.repositories.user_repo import user_repo

logger = get_logger("api.sponsors.bids")
router = APIRouter(dependencies=[Depends(require_feature("feature_sponsors_enabled"))])


async def _bid_to_response(db, bid) -> dict:
    profile = await sponsor_svc.get_profile(db, bid.sponsor_user_id)
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
    else:
        user = await user_repo.get_by_id(db, bid.sponsor_user_id)
        fallback_name = user.display_name if user else "Unknown"
        profile_data = {
            "id": 0,
            "user_id": bid.sponsor_user_id,
            "company_name": fallback_name,
            "contact_name": (user.display_name or "") if user else "",
            "profession": "",
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
)
async def place_bid(
    event_id: int,
    cat_id: int,
    data: BidCreate,
    db: DbSession,
    current_user: CurrentUser,
    _kyc=Depends(require_kyc()),
):
    log_step(logger, "Placing bid", event_id=event_id, cat_id=cat_id, user_id=current_user.id, amount_cents=data.amount_cents)
    bid = await sponsor_svc.place_bid(db, cat_id, current_user, data)
    return await _bid_to_response(db, bid)


@router.patch(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}",
    response_model=BidResponse,
)
async def update_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    data: BidUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Updating bid", event_id=event_id, cat_id=cat_id, bid_id=bid_id, user_id=current_user.id)
    bid = await sponsor_svc.update_bid(db, bid_id, current_user, data)
    return await _bid_to_response(db, bid)


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/withdraw",
    response_model=BidResponse,
)
async def withdraw_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Withdrawing bid", event_id=event_id, cat_id=cat_id, bid_id=bid_id, user_id=current_user.id)
    bid = await sponsor_svc.withdraw_bid(db, bid_id, current_user)
    return await _bid_to_response(db, bid)


@router.get(
    "/events/{event_id}/sponsorships/{cat_id}/bids",
    response_model=list[BidResponse],
)
async def list_bids(
    event_id: int,
    cat_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    bids = await sponsor_svc.list_bids(db, cat_id, current_user)
    return [await _bid_to_response(db, b) for b in bids]


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/accept",
    response_model=BidResponse,
)
async def accept_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Accepting bid", event_id=event_id, cat_id=cat_id, bid_id=bid_id, user_id=current_user.id)
    bid = await sponsor_svc.accept_bid(db, bid_id, current_user)
    return await _bid_to_response(db, bid)


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/reject",
    response_model=BidResponse,
)
async def reject_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Rejecting bid", event_id=event_id, cat_id=cat_id, bid_id=bid_id, user_id=current_user.id)
    bid = await sponsor_svc.reject_bid(db, bid_id, current_user)
    return await _bid_to_response(db, bid)
