"""Sponsor bid endpoints."""
from fastapi import APIRouter, Depends

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature, require_kyc
from app.logger import get_logger, log_step
from app.schemas.sponsor import BidCreate, BidUpdate, BidResponse
from app.services import sponsor as sponsor_svc
from app.services import notification_service as notif_svc
from app.models.notification import NotificationType
from app.repositories.sponsor_repo import sponsor_repo
from app.repositories.user_repo import user_repo
from app.worker.redis_pool import enqueue as arq_enqueue

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
    logger.debug("Bid proposal", extra={"proposal_length": len(data.proposal_text or "")})
    bid = await sponsor_svc.place_bid(db, cat_id, current_user, data)
    cat = await sponsor_repo.get_category(db, cat_id)
    event = await sponsor_repo.get_event(db, cat.event_id)
    await notif_svc.create_notification(
        db, user_id=event.organizer_id,
        type=NotificationType.bid_received,
        title="New Sponsor Bid",
        message=f"A new bid of ${data.amount_cents / 100:.2f} was placed on '{cat.name}'.",
        data={"event_id": cat.event_id, "category_id": cat_id, "bid_id": bid.id},
    )
    await db.commit()
    await sponsor_repo.refresh(db, bid)
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
    await db.commit()
    await sponsor_repo.refresh(db, bid)
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
    event_obj = await sponsor_repo.get_event(db, event_id)
    if event_obj:
        await notif_svc.create_notification(
            db, user_id=event_obj.organizer_id,
            type=NotificationType.bid_rejected,
            title="Bid Withdrawn",
            message="A sponsor has withdrawn their bid.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id},
        )
    await db.commit()
    await sponsor_repo.refresh(db, bid)
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
    await notif_svc.create_notification(
        db, user_id=bid.sponsor_user_id,
        type=NotificationType.bid_accepted,
        title="Bid Accepted",
        message="Your sponsorship bid has been accepted!",
        data={"event_id": event_id, "category_id": cat_id, "bid_id": bid.id},
    )
    await db.commit()
    await sponsor_repo.refresh(db, bid)
    sponsor = await user_repo.get_by_id(db, bid.sponsor_user_id)
    cat = await sponsor_repo.get_category(db, bid.category_id)
    event = await sponsor_repo.get_event(db, event_id)
    if sponsor and sponsor.email:
        await arq_enqueue(
            "send_sponsor_bid_approved_email",
            sponsor_email=sponsor.email,
            sponsor_name=sponsor.display_name or "",
            event_title=event.title if event else f"Event #{event_id}",
            category_name=cat.name if cat else f"Category #{cat_id}",
            bid_amount_cents=bid.amount_cents,
        )
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
    await notif_svc.create_notification(
        db, user_id=bid.sponsor_user_id,
        type=NotificationType.bid_rejected,
        title="Bid Rejected",
        message="Your sponsorship bid was not accepted.",
        data={"event_id": event_id, "category_id": cat_id, "bid_id": bid.id},
    )
    await db.commit()
    await sponsor_repo.refresh(db, bid)
    sponsor = await user_repo.get_by_id(db, bid.sponsor_user_id)
    cat = await sponsor_repo.get_category(db, bid.category_id)
    event = await sponsor_repo.get_event(db, event_id)
    if sponsor and sponsor.email:
        await arq_enqueue(
            "send_sponsor_bid_rejected_email",
            sponsor_email=sponsor.email,
            sponsor_name=sponsor.display_name or "",
            event_title=event.title if event else f"Event #{event_id}",
            category_name=cat.name if cat else f"Category #{cat_id}",
            bid_amount_cents=bid.amount_cents,
        )
    return await _bid_to_response(db, bid)
