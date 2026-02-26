"""Sponsor payment and refund; sponsor ticket creation."""
import secrets
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.sponsor import (
    SponsorBid,
    SponsorPayment,
    SponsorTicket,
    SponsorshipCategory,
    BidStatus,
    PaymentStatus,
)

from app.services.sponsor.categories import _get_category, list_categories, _require_organizer


async def _ensure_sponsor_ticket(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> SponsorTicket:
    """Create or update sponsor ticket with QR data."""
    existing = (await db.execute(
        select(SponsorTicket).where(
            SponsorTicket.event_id == event_id,
            SponsorTicket.sponsor_user_id == sponsor_user_id,
        )
    )).scalar_one_or_none()

    from app.services.ticket_crypto import encrypt_ticket_qr
    ticket_code = secrets.token_hex(16)

    if existing:
        existing.qr_data_encrypted = encrypt_ticket_qr(
            ticket_code, event_id, existing.id
        )
        await db.flush()
        await db.refresh(existing)
        return existing

    now = datetime.utcnow()
    ticket = SponsorTicket(
        event_id=event_id,
        sponsor_user_id=sponsor_user_id,
        receipt_number=f"SPT-{now.strftime('%Y%m%d')}-{event_id}-0",
    )
    db.add(ticket)
    await db.flush()
    await db.refresh(ticket)

    ticket.receipt_number = f"SPT-{now.strftime('%Y%m%d')}-{event_id}-{ticket.id}"
    ticket.qr_data_encrypted = encrypt_ticket_qr(
        ticket_code, event_id, ticket.id
    )
    await db.flush()
    await db.refresh(ticket)
    return ticket


async def pay_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorPayment:
    """Sponsor pays for an accepted bid. Creates payment + auto-generates sponsor ticket."""
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")
    if bid.sponsor_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your bid")
    if bid.status != BidStatus.accepted:
        raise HTTPException(status_code=400, detail="Can only pay for accepted bids")

    existing_payment = (await db.execute(
        select(SponsorPayment).where(SponsorPayment.bid_id == bid_id)
    )).scalar_one_or_none()
    if existing_payment:
        raise HTTPException(status_code=409, detail="Bid already paid")

    from app.services import platform_settings as settings_svc
    commission_pct = await settings_svc.get_int(db, "sponsor_commission_percent")
    cat = (await db.execute(
        select(SponsorshipCategory).where(SponsorshipCategory.id == bid.category_id)
    )).scalar_one_or_none()

    if cat and cat.event_id:
        from app.models.event import Event
        event = (await db.execute(select(Event).where(Event.id == cat.event_id))).scalar_one_or_none()
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
    db.add(payment)

    bid.status = BidStatus.paid
    await db.flush()
    await db.refresh(payment)

    cat = await _get_category(db, bid.category_id)
    await _ensure_sponsor_ticket(db, cat.event_id, user.id)

    try:
        from app.services import sponsor_escrow as se_svc
        await se_svc.get_or_create(db, event_id=cat.event_id)
        await se_svc.refresh_total(db, cat.event_id)
    except Exception:
        pass

    return payment


async def refund_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorPayment:
    """Organizer refunds a paid bid."""
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")

    cat = await _get_category(db, bid.category_id)
    await _require_organizer(db, cat.event_id, user)

    if bid.status != BidStatus.paid:
        raise HTTPException(status_code=400, detail="Can only refund paid bids")

    payment = (await db.execute(
        select(SponsorPayment).where(SponsorPayment.bid_id == bid_id)
    )).scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.status != PaymentStatus.completed:
        raise HTTPException(status_code=400, detail="Payment already refunded")

    payment.status = PaymentStatus.refund_processing
    bid.status = BidStatus.rejected
    if cat.filled_spots > 0:
        cat.filled_spots -= 1

    from sqlalchemy import func
    other_active = (await db.execute(
        select(func.count()).select_from(SponsorBid).where(
            SponsorBid.sponsor_user_id == bid.sponsor_user_id,
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid]),
            SponsorBid.id != bid.id,
            SponsorBid.category_id.in_(
                select(SponsorshipCategory.id).where(SponsorshipCategory.event_id == cat.event_id)
            ),
        )
    )).scalar_one()

    refunded_with_payment = (await db.execute(
        select(func.count()).select_from(SponsorBid)
        .join(SponsorPayment, SponsorPayment.bid_id == SponsorBid.id)
        .where(
            SponsorBid.sponsor_user_id == bid.sponsor_user_id,
            SponsorPayment.status.in_([PaymentStatus.refunded, PaymentStatus.refund_processing]),
            SponsorBid.category_id.in_(
                select(SponsorshipCategory.id).where(SponsorshipCategory.event_id == cat.event_id)
            ),
        )
    )).scalar_one()

    if other_active == 0 and refunded_with_payment == 0:
        from sqlalchemy import delete as sa_delete
        await db.execute(
            sa_delete(SponsorTicket).where(
                SponsorTicket.event_id == cat.event_id,
                SponsorTicket.sponsor_user_id == bid.sponsor_user_id,
            )
        )

    payment.status = PaymentStatus.refunded
    await db.flush()
    await db.refresh(payment)
    return payment


async def refund_all_sponsor_payments_for_event(db: AsyncSession, event_id: int) -> int:
    """Mark all completed sponsor payments as refunded; reset bids and delete sponsor tickets. Returns count."""
    cats = await list_categories(db, event_id)
    cat_ids = [c.id for c in cats]
    if not cat_ids:
        return 0

    paid_bids_q = select(SponsorBid).where(
        SponsorBid.category_id.in_(cat_ids),
        SponsorBid.status == BidStatus.paid,
    )
    paid_bids = list((await db.execute(paid_bids_q)).scalars().all())

    refund_payment_ids = []
    refunded_count = 0
    for bid in paid_bids:
        payment = (await db.execute(
            select(SponsorPayment).where(SponsorPayment.bid_id == bid.id)
        )).scalar_one_or_none()
        if payment and payment.status == PaymentStatus.completed:
            payment.status = PaymentStatus.refund_processing
            refund_payment_ids.append(payment.id)
            refunded_count += 1

        cat = next((c for c in cats if c.id == bid.category_id), None)
        if cat and cat.filled_spots > 0:
            cat.filled_spots -= 1

        bid.status = BidStatus.rejected

    accepted_bids_q = select(SponsorBid).where(
        SponsorBid.category_id.in_(cat_ids),
        SponsorBid.status == BidStatus.accepted,
    )
    accepted_bids = list((await db.execute(accepted_bids_q)).scalars().all())
    for bid in accepted_bids:
        cat = next((c for c in cats if c.id == bid.category_id), None)
        if cat and cat.filled_spots > 0:
            cat.filled_spots -= 1
        bid.status = BidStatus.rejected

    from sqlalchemy import delete as sa_delete
    await db.execute(
        sa_delete(SponsorTicket).where(SponsorTicket.event_id == event_id)
    )

    await db.flush()

    from app.worker.redis_pool import enqueue
    for pid in refund_payment_ids:
        await enqueue("process_sponsor_refund", pid)

    return refunded_count
