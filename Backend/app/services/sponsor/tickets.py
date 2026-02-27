"""Sponsor ticket list, won categories, scan."""
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event
from app.models.sponsor import (
    SponsorBid,
    SponsorDelegate,
    SponsorPayment,
    SponsorTicket,
    SponsorshipCategory,
    BidStatus,
    PaymentStatus,
)

from app.services.sponsor.profile import get_profile


async def get_sponsor_ticket(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> SponsorTicket | None:
    return (await db.execute(
        select(SponsorTicket).where(
            SponsorTicket.event_id == event_id,
            SponsorTicket.sponsor_user_id == sponsor_user_id,
        )
    )).scalar_one_or_none()


async def list_sponsor_tickets(
    db: AsyncSession, sponsor_user_id: int
) -> list[SponsorTicket]:
    q = (
        select(SponsorTicket)
        .where(SponsorTicket.sponsor_user_id == sponsor_user_id)
        .options(selectinload(SponsorTicket.event).selectinload(Event.venue))
        .order_by(SponsorTicket.created_at.desc())
    )
    return list((await db.execute(q)).scalars().all())


async def get_won_categories(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> list[dict]:
    """Return category info where sponsor has accepted, paid, or refunded bids."""
    from app.models.prerequisite import CategoryPrerequisite, BidPrerequisiteUpload
    q = (
        select(
            SponsorshipCategory.id,
            SponsorshipCategory.name,
            SponsorBid.id.label("bid_id"),
            SponsorBid.amount_cents,
            SponsorBid.status,
        )
        .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorBid.sponsor_user_id == sponsor_user_id,
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid, BidStatus.rejected]),
        )
    )
    rows = (await db.execute(q)).all()

    filtered = []
    for r in rows:
        if r.status == BidStatus.rejected:
            payment = (await db.execute(
                select(SponsorPayment).where(SponsorPayment.bid_id == r.bid_id)
            )).scalar_one_or_none()
            if not payment or payment.status != PaymentStatus.refunded:
                continue
        filtered.append(r)

    results = []
    for r in filtered:
        prereqs_q = select(CategoryPrerequisite).where(
            CategoryPrerequisite.category_id == r.id,
        )
        prereqs = (await db.execute(prereqs_q)).scalars().all()
        prereq_list = []
        for p in prereqs:
            upload = (await db.execute(
                select(BidPrerequisiteUpload).where(
                    BidPrerequisiteUpload.bid_id == r.bid_id,
                    BidPrerequisiteUpload.prerequisite_id == p.id,
                )
            )).scalar_one_or_none()
            prereq_list.append({
                "id": p.id,
                "name": p.name,
                "is_required": p.is_required,
                "requires_document": p.requires_document,
                "upload_status": upload.status.value if upload else None,
            })

        payment = (await db.execute(
            select(SponsorPayment).where(SponsorPayment.bid_id == r.bid_id)
        )).scalar_one_or_none()

        cat_status = r.status.value
        if r.status == BidStatus.rejected and payment and payment.status == PaymentStatus.refunded:
            cat_status = "refunded"

        results.append({
            "name": r.name,
            "amount_cents": r.amount_cents,
            "status": cat_status,
            "prerequisites": prereq_list,
            "bid_id": r.bid_id,
            "payment_id": payment.id if payment else None,
            "payment_receipt_number": payment.receipt_number if payment else None,
            "payment_status": payment.status.value if payment else None,
            "payment_created_at": payment.created_at.isoformat() if payment and payment.created_at else None,
        })
    return results


async def scan_sponsor_ticket(
    db: AsyncSession, event_id: int, encrypted_payload: str
) -> dict:
    """Decrypt QR and return sponsor info + won categories."""
    from app.services.ticket_crypto import decrypt_ticket_qr
    try:
        data = decrypt_ticket_qr(encrypted_payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    ticket_event_id = data.get("eid")
    ticket_id = data.get("sid")
    if ticket_event_id != event_id:
        raise HTTPException(status_code=400, detail="QR does not belong to this event")

    ticket = (await db.execute(
        select(SponsorTicket)
        .options(selectinload(SponsorTicket.delegates))
        .where(SponsorTicket.id == ticket_id)
    )).scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Sponsor ticket not found")

    from datetime import datetime
    already_scanned = ticket.scanned_at is not None
    delegates = ticket.delegates or []
    has_delegates = len(delegates) > 0

    if not has_delegates:
        if not ticket.scanned_at:
            ticket.scanned_at = datetime.utcnow()
        ticket.scan_count = (ticket.scan_count or 0) + 1
        await db.flush()

    profile = await get_profile(db, ticket.sponsor_user_id)
    cats = await get_won_categories(db, event_id, ticket.sponsor_user_id)

    delegate_list = [
        {
            "id": d.id,
            "name": d.name,
            "email": d.email,
            "phone": d.phone,
            "checked_in": d.checked_in,
            "checked_in_at": d.checked_in_at.isoformat() if d.checked_in_at else None,
        }
        for d in sorted(delegates, key=lambda d: (d.checked_in, d.created_at))
    ]

    return {
        "ticket_id": ticket.id,
        "receipt_number": ticket.receipt_number,
        "company_name": profile.company_name if profile else "Unknown",
        "contact_name": profile.contact_name if profile else "",
        "categories": cats,
        "category_names": [c["name"] for c in cats],
        "category_count": len(cats),
        "already_scanned": already_scanned,
        "scan_count": ticket.scan_count or 0,
        "delegates": delegate_list,
        "total_delegates": len(delegates),
        "checked_in_count": sum(1 for d in delegates if d.checked_in),
        "unchecked_count": sum(1 for d in delegates if not d.checked_in),
    }
