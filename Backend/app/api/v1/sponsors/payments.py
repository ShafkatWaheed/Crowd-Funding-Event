"""Sponsor payment and receipt endpoints."""
from fastapi import APIRouter, Depends, HTTPException, Request

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature, require_kyc
from app.logger import get_logger, log_step
from app.rate_limit import limiter, dynamic_limit
from app.models.user import UserRole
from app.schemas.sponsor import PaymentResponse
from app.services import sponsor as sponsor_svc
from app.repositories.sponsor_repo import sponsor_repo
from app.repositories.user_repo import user_repo

logger = get_logger("api.sponsors.payments")
router = APIRouter(dependencies=[Depends(require_feature("feature_sponsors_enabled"))])


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/pay",
    response_model=PaymentResponse,
)
@limiter.limit(dynamic_limit("payment_action", "10/minute"))
async def pay_bid(
    request: Request,
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
    _kyc=Depends(require_kyc()),
):
    log_step(logger, "Paying bid", event_id=event_id, cat_id=cat_id, bid_id=bid_id, user_id=current_user.id)
    payment = await sponsor_svc.pay_bid(db, bid_id, current_user)
    await db.commit()
    return payment


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/refund",
    response_model=PaymentResponse,
)
@limiter.limit(dynamic_limit("payment_action", "10/minute"))
async def refund_bid(
    request: Request,
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Refunding bid", event_id=event_id, cat_id=cat_id, bid_id=bid_id, user_id=current_user.id)
    payment = await sponsor_svc.refund_bid(db, bid_id, current_user)
    await db.commit()
    return payment


@router.get("/payments/{payment_id}/receipt")
async def get_sponsor_payment_receipt(
    payment_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    from app.services import event as event_service
    payment = await sponsor_repo.get_payment_by_id(db, payment_id)
    if not payment:
        logger.warning("Payment not found", extra={"payment_id": payment_id, "user_id": current_user.id})
        raise HTTPException(status_code=404, detail="Payment not found")
    bid = await sponsor_repo.get_bid(db, payment.bid_id)
    if not bid:
        logger.warning("Bid not found for receipt", extra={"payment_id": payment_id, "bid_id": payment.bid_id})
        raise HTTPException(status_code=404, detail="Bid not found")
    if bid.sponsor_user_id != current_user.id and current_user.role != UserRole.admin:
        cat_check = await sponsor_repo.get_category(db, bid.category_id)
        if not cat_check:
            logger.warning("Not authorized to view receipt", extra={"payment_id": payment_id, "user_id": current_user.id})
            raise HTTPException(status_code=403, detail="Not authorized")
        evt_check = await sponsor_repo.get_event(db, cat_check.event_id)
        if not evt_check or evt_check.organizer_id != current_user.id:
            logger.warning("Not authorized to view receipt", extra={"payment_id": payment_id, "user_id": current_user.id})
            raise HTTPException(status_code=403, detail="Not authorized")
    cat = await sponsor_repo.get_category(db, bid.category_id)
    event = await event_service.get_by_id(db, cat.event_id, load_venue=True) if cat else None
    sponsor = await user_repo.get_by_id(db, bid.sponsor_user_id)
    is_refund = payment.status.value in ("refunded", "refund_processing")
    return {
        "payment_id": payment.id,
        "receipt_number": payment.receipt_number,
        "type": "refund" if is_refund else "payment",
        "amount_cents": payment.amount_cents,
        "platform_cut_cents": payment.platform_cut_cents,
        "net_to_organizer_cents": payment.net_to_organizer_cents,
        "subtotal_cents": getattr(payment, "subtotal_cents", 0),
        "tax_cents": getattr(payment, "tax_cents", 0),
        "tax_rate": getattr(payment, "tax_rate", 0.0),
        "status": payment.status.value,
        "created_at": payment.created_at.isoformat() if payment.created_at else None,
        "bid_id": bid.id,
        "bid_amount_cents": bid.amount_cents,
        "bid_proposal": bid.proposal_text,
        "category_name": cat.name if cat else None,
        "event_id": cat.event_id if cat else None,
        "event_title": event.title if event else None,
        "event_start_time": event.start_time.isoformat() if event and event.start_time else None,
        "venue_name": event.venue.name if event and event.venue else None,
        "venue_city": event.venue.city if event and event.venue else None,
        "sponsor_name": sponsor.display_name if sponsor else None,
        "sponsor_email": sponsor.email if sponsor else None,
    }
