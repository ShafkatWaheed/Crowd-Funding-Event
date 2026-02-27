"""Sponsor payment and receipt endpoints."""
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature
from app.rate_limit import limiter, dynamic_limit
from app.models.user import UserRole
from app.models.sponsor import SponsorPayment, SponsorBid, SponsorshipCategory
from app.models.event import Event
from app.models.user import User
from app.schemas.sponsor import PaymentResponse
from app.services import sponsor as sponsor_svc
from app.services import notification_service as notif_svc
from app.models.notification import NotificationType
from app.worker.redis_pool import enqueue as arq_enqueue

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
):
    payment = await sponsor_svc.pay_bid(db, bid_id, current_user)
    from sqlalchemy import select as sa_select
    event_obj = (await db.execute(
        sa_select(Event).where(Event.id == event_id)
    )).scalar_one_or_none()
    if event_obj:
        await notif_svc.create_notification(
            db, user_id=event_obj.organizer_id,
            type=NotificationType.sponsor_payment_received,
            title="Sponsor Payment Received",
            message=f"A sponsor has paid ${payment.amount_cents / 100:.2f} for their sponsorship.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id, "payment_id": payment.id},
        )
    await db.commit()
    await db.refresh(payment)
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
    from sqlalchemy import select as sa_select
    bid_obj = (await db.execute(
        sa_select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    sponsor_user_id = bid_obj.sponsor_user_id if bid_obj else None
    payment = await sponsor_svc.refund_bid(db, bid_id, current_user)
    if sponsor_user_id:
        await notif_svc.create_notification(
            db, user_id=sponsor_user_id,
            type=NotificationType.sponsor_refunded,
            title="Sponsorship Refunded",
            message=f"Your sponsorship payment of ${payment.amount_cents / 100:.2f} has been refunded by the organizer.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id, "payment_id": payment.id},
        )
    event_obj = (await db.execute(
        sa_select(Event).where(Event.id == event_id)
    )).scalar_one_or_none()
    if event_obj:
        await notif_svc.create_notification(
            db, user_id=event_obj.organizer_id,
            type=NotificationType.sponsor_refunded,
            title="Sponsorship Refund Processed",
            message=f"Refund of ${payment.amount_cents / 100:.2f} has been processed for bid #{bid_id}.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id, "payment_id": payment.id},
        )
    await db.commit()
    await db.refresh(payment)
    if sponsor_user_id:
        sponsor = (await db.execute(select(User).where(User.id == sponsor_user_id))).scalar_one_or_none()
        cat = (await db.execute(select(SponsorshipCategory).where(SponsorshipCategory.id == cat_id))).scalar_one_or_none()
        if sponsor and sponsor.email:
            await arq_enqueue(
                "send_sponsor_refund_email",
                sponsor_email=sponsor.email,
                sponsor_name=sponsor.display_name or "",
                event_title=event_obj.title if event_obj else f"Event #{event_id}",
                category_name=cat.name if cat else f"Category #{cat_id}",
                refunded_cents=payment.amount_cents,
                receipt_number=getattr(payment, "receipt_number", None),
            )
    return payment


@router.get("/payments/{payment_id}/receipt")
async def get_sponsor_payment_receipt(
    payment_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    payment = (await db.execute(
        select(SponsorPayment).where(SponsorPayment.id == payment_id)
    )).scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == payment.bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")
    if bid.sponsor_user_id != current_user.id and current_user.role != UserRole.admin:
        cat_check = (await db.execute(
            select(SponsorshipCategory).where(SponsorshipCategory.id == bid.category_id)
        )).scalar_one_or_none()
        if not cat_check:
            raise HTTPException(status_code=403, detail="Not authorized")
        evt_check = (await db.execute(
            select(Event).where(Event.id == cat_check.event_id)
        )).scalar_one_or_none()
        if not evt_check or evt_check.organizer_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not authorized")
    cat = (await db.execute(
        select(SponsorshipCategory).where(SponsorshipCategory.id == bid.category_id)
    )).scalar_one_or_none()
    event = (await db.execute(
        select(Event).options(selectinload(Event.venue)).where(Event.id == cat.event_id)
    )).scalar_one_or_none() if cat else None
    sponsor = (await db.execute(
        select(User).where(User.id == bid.sponsor_user_id)
    )).scalar_one_or_none()
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
