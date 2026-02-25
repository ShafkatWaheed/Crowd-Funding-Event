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
    platform_cut = (bid.amount_cents * commission_pct) // 100
    net = bid.amount_cents - platform_cut

    now = datetime.utcnow()
    receipt = f"SP-{now.strftime('%Y%m%d')}-{bid.category_id}-{bid_id}"

    payment = SponsorPayment(
        bid_id=bid_id,
        amount_cents=bid.amount_cents,
        platform_cut_cents=platform_cut,
        net_to_organizer_cents=net,
        receipt_number=receipt,
    )
    db.add(payment)

    bid.status = BidStatus.paid
    await db.flush()
    await db.refresh(payment)

    cat = await _get_category(db, bid.category_id)
    await _ensure_sponsor_ticket(db, cat.event_id, user.id)

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

    refunded_count = 0
    for bid in paid_bids:
        payment = (await db.execute(
            select(SponsorPayment).where(SponsorPayment.bid_id == bid.id)
        )).scalar_one_or_none()
        if payment and payment.status == PaymentStatus.completed:
            payment.status = PaymentStatus.refund_processing
            refunded_count += 1
            payment.status = PaymentStatus.refunded

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
    return refunded_count
