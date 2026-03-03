"""Sponsor payment and refund; sponsor ticket creation."""
import secrets
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.user import User
from app.models.notification import NotificationType
from app.models.sponsor import (
    SponsorBid,
    SponsorPayment,
    SponsorTicket,
    BidStatus,
    PaymentStatus,
)
from app.repositories.sponsor_repo import sponsor_repo
from app.repositories.user_repo import user_repo
from app.services import notification_service as notif_svc
from app.worker.redis_pool import enqueue as arq_enqueue

from app.services.sponsor.categories import _get_category, list_categories, _require_organizer

logger = get_logger("svc.sponsor.payments")


async def _ensure_sponsor_ticket(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> SponsorTicket:
    """Create or update sponsor ticket with QR data."""
    existing = await sponsor_repo.get_sponsor_ticket(db, event_id, sponsor_user_id)

    from app.services.ticket_crypto import encrypt_ticket_qr
    ticket_code = secrets.token_hex(16)

    if existing:
        existing.qr_data_encrypted = encrypt_ticket_qr(
            ticket_code, event_id, existing.id
        )
        return await sponsor_repo.update_sponsor_ticket(db, existing)

    now = datetime.utcnow()
    ticket = SponsorTicket(
        event_id=event_id,
        sponsor_user_id=sponsor_user_id,
        receipt_number=f"SPT-{now.strftime('%Y%m%d')}-{event_id}-0",
    )
    ticket = await sponsor_repo.create_sponsor_ticket(db, ticket)

    ticket.receipt_number = f"SPT-{now.strftime('%Y%m%d')}-{event_id}-{ticket.id}"
    ticket.qr_data_encrypted = encrypt_ticket_qr(
        ticket_code, event_id, ticket.id
    )
    return await sponsor_repo.update_sponsor_ticket(db, ticket)


async def pay_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorPayment:
    log_step(logger, "Process sponsor payment", bid_id=bid_id, user_id=user.id)
    bid = await sponsor_repo.get_bid(db, bid_id)
    if not bid:
        logger.warning("Pay bid: not found", extra={"bid_id": bid_id})
        raise HTTPException(status_code=404, detail="Bid not found")
    if bid.sponsor_user_id != user.id:
        logger.warning("Pay bid: not owner", extra={"bid_id": bid_id, "user_id": user.id})
        raise HTTPException(status_code=403, detail="Not your bid")
    if bid.status != BidStatus.accepted:
        logger.warning("Pay bid: not accepted", extra={"bid_id": bid_id, "status": bid.status.value})
        raise HTTPException(status_code=400, detail="Can only pay for accepted bids")

    existing_payment = await sponsor_repo.get_payment_by_bid(db, bid_id)
    if existing_payment:
        logger.warning("Pay bid: already paid", extra={"bid_id": bid_id})
        raise HTTPException(status_code=409, detail="Bid already paid")

    from app.services import platform_settings as settings_svc
    commission_pct = await settings_svc.get_int(db, "sponsor_commission_percent")
    cat = await sponsor_repo.get_category(db, bid.category_id)

    if cat and cat.event_id:
        event = await sponsor_repo.get_event(db, cat.event_id)
        if event:
            from app.services.age_verification import enforce_age_limit
            enforce_age_limit(user.birthday, event.age_restricted, event.min_age, "sponsor this event")
            if getattr(event, "community_rules", False):
                override = await settings_svc.get_str(db, "community_sponsor_commission_percent")
                if override is not None and override != "":
                    commission_pct = int(override)
    platform_cut = (bid.amount_cents * commission_pct) // 100
    net = bid.amount_cents - platform_cut

    gateway_txn_id: str | None = None
    gateway_auth: str | None = None
    if bid.amount_cents > 0:
        try:
            from app.services.payment_gateway import get_gateway
            gw = await get_gateway(db)
            result = await gw.charge(
                db,
                user_id=user.id,
                amount_cents=bid.amount_cents,
                description=f"Sponsor payment for bid {bid_id}",
                idempotency_key=f"sponsor-bid-{bid_id}",
                commission_cents=platform_cut,
            )
            if result.status == "failed":
                raise HTTPException(status_code=402, detail=f"Payment failed: {getattr(result, 'failure_reason', 'card declined')}")
            gateway_txn_id = result.transaction_id
            gateway_auth = result.authorization_code
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(status_code=402, detail=f"Payment processing error: {exc}")

    now = datetime.utcnow()
    receipt = f"SP-{now.strftime('%Y%m%d')}-{bid.category_id}-{bid_id}"

    payment = SponsorPayment(
        bid_id=bid_id,
        amount_cents=bid.amount_cents,
        platform_cut_cents=platform_cut,
        net_to_organizer_cents=net,
        receipt_number=receipt,
        gateway_transaction_id=gateway_txn_id,
        gateway_auth_code=gateway_auth,
    )
    payment = await sponsor_repo.create_sponsor_payment(db, payment)

    bid.status = BidStatus.paid
    await sponsor_repo.update_bid_status(db, bid)

    cat = await _get_category(db, bid.category_id)
    await _ensure_sponsor_ticket(db, cat.event_id, user.id)

    try:
        from app.services import sponsor_escrow as se_svc
        await se_svc.get_or_create(db, event_id=cat.event_id)
        await se_svc.refresh_total(db, cat.event_id)
    except Exception:
        pass

    event = await sponsor_repo.get_event(db, cat.event_id)
    if event:
        await notif_svc.create_notification(
            db, user_id=event.organizer_id,
            type=NotificationType.sponsor_payment_received,
            title="Sponsor Payment Received",
            message=f"A sponsor has paid ${payment.amount_cents / 100:.2f} for their sponsorship.",
            data={"event_id": cat.event_id, "category_id": bid.category_id, "bid_id": bid_id, "payment_id": payment.id},
        )

    await db.commit()
    await sponsor_repo.refresh(db, payment)
    logger.info("Sponsor payment completed", extra={"payment_id": payment.id, "bid_id": bid_id, "amount_cents": bid.amount_cents})
    return payment


async def refund_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorPayment:
    log_step(logger, "Refund sponsor bid", bid_id=bid_id, user_id=user.id)
    bid = await sponsor_repo.get_bid(db, bid_id)
    if not bid:
        logger.warning("Refund bid: not found", extra={"bid_id": bid_id})
        raise HTTPException(status_code=404, detail="Bid not found")

    cat = await _get_category(db, bid.category_id)
    await _require_organizer(db, cat.event_id, user)

    if bid.status != BidStatus.paid:
        logger.warning("Refund bid: not paid", extra={"bid_id": bid_id, "status": bid.status.value})
        raise HTTPException(status_code=400, detail="Can only refund paid bids")

    payment = await sponsor_repo.get_payment_by_bid(db, bid_id)
    if not payment:
        logger.warning("Refund bid: payment not found", extra={"bid_id": bid_id})
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.status != PaymentStatus.completed:
        logger.warning("Refund bid: payment not completed", extra={"bid_id": bid_id})
        raise HTTPException(status_code=400, detail="Payment already refunded")

    payment.status = PaymentStatus.refund_processing
    bid.status = BidStatus.rejected
    if cat.filled_spots > 0:
        cat.filled_spots -= 1

    other_active = await sponsor_repo.count_other_active_bids_for_event(
        db, bid.sponsor_user_id, cat.event_id, bid.id
    )

    refunded_with_payment = await sponsor_repo.count_refunded_bids_for_event(
        db, bid.sponsor_user_id, cat.event_id
    )

    if other_active == 0 and refunded_with_payment == 0:
        await sponsor_repo.delete_sponsor_tickets_for_event(
            db, cat.event_id, bid.sponsor_user_id
        )

    await sponsor_repo.flush(db)
    payment = await sponsor_repo.get_payment_by_bid(db, bid_id)

    await arq_enqueue("process_sponsor_refund", payment.id)

    await notif_svc.create_notification(
        db, user_id=bid.sponsor_user_id,
        type=NotificationType.sponsor_refunded,
        title="Sponsorship Refunded",
        message=f"Your sponsorship refund of ${payment.amount_cents / 100:.2f} is being processed.",
        data={"event_id": cat.event_id, "category_id": bid.category_id, "bid_id": bid_id, "payment_id": payment.id},
    )
    event = await sponsor_repo.get_event(db, cat.event_id)
    if event:
        await notif_svc.create_notification(
            db, user_id=event.organizer_id,
            type=NotificationType.sponsor_refunded,
            title="Sponsorship Refund Processed",
            message=f"Refund of ${payment.amount_cents / 100:.2f} is being processed for bid #{bid_id}.",
            data={"event_id": cat.event_id, "category_id": bid.category_id, "bid_id": bid_id, "payment_id": payment.id},
        )

    await db.commit()
    await sponsor_repo.refresh(db, payment)

    sponsor = await user_repo.get_by_id(db, bid.sponsor_user_id)
    if sponsor and sponsor.email:
        await arq_enqueue(
            "send_sponsor_refund_email",
            sponsor_email=sponsor.email,
            sponsor_name=sponsor.display_name or "",
            event_title=event.title if event else f"Event #{cat.event_id}",
            category_name=cat.name,
            refunded_cents=payment.amount_cents,
            receipt_number=getattr(payment, "receipt_number", None),
        )

    logger.info("Sponsor refund initiated", extra={"payment_id": payment.id, "bid_id": bid_id})
    return payment


async def refund_all_sponsor_payments_for_event(db: AsyncSession, event_id: int) -> int:
    """Mark all completed sponsor payments as refunded; reset bids and delete sponsor tickets. Returns count."""
    cats = await list_categories(db, event_id)
    cat_ids = [c.id for c in cats]
    if not cat_ids:
        return 0

    paid_bids = await sponsor_repo.get_paid_bids_for_categories(db, cat_ids)

    refund_payment_ids = []
    refunded_count = 0
    for bid in paid_bids:
        payment = await sponsor_repo.get_payment_by_bid(db, bid.id)
        if payment and payment.status == PaymentStatus.completed:
            payment.status = PaymentStatus.refund_processing
            refund_payment_ids.append(payment.id)
            refunded_count += 1

        cat = next((c for c in cats if c.id == bid.category_id), None)
        if cat and cat.filled_spots > 0:
            cat.filled_spots -= 1

        bid.status = BidStatus.rejected

    accepted_bids = await sponsor_repo.get_accepted_bids_for_categories(db, cat_ids)
    for bid in accepted_bids:
        cat = next((c for c in cats if c.id == bid.category_id), None)
        if cat and cat.filled_spots > 0:
            cat.filled_spots -= 1
        bid.status = BidStatus.rejected

    await sponsor_repo.delete_sponsor_tickets_for_event(db, event_id)
    await sponsor_repo.flush(db)

    from app.worker.redis_pool import enqueue
    for pid in refund_payment_ids:
        await enqueue("process_sponsor_refund", pid)

    return refunded_count
