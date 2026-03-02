"""Sponsor ticket list, won categories, scan."""
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sponsor import (
    SponsorTicket,
    BidStatus,
    PaymentStatus,
)
from app.repositories.sponsor_repo import sponsor_repo

from app.services.sponsor.profile import get_profile


async def get_sponsor_ticket(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> SponsorTicket | None:
    return await sponsor_repo.get_sponsor_ticket(db, event_id, sponsor_user_id)


async def list_sponsor_tickets(
    db: AsyncSession, sponsor_user_id: int
) -> list[SponsorTicket]:
    return await sponsor_repo.list_sponsor_tickets(db, sponsor_user_id)


async def get_won_categories(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> list[dict]:
    """Return category info where sponsor has accepted, paid, or refunded bids."""
    rows = await sponsor_repo.get_won_category_rows(db, event_id, sponsor_user_id)

    filtered = []
    for r in rows:
        if r.status == BidStatus.rejected:
            payment = await sponsor_repo.get_payment_by_bid(db, r.bid_id)
            if not payment or payment.status != PaymentStatus.refunded:
                continue
        filtered.append(r)

    results = []
    for r in filtered:
        prereqs = await sponsor_repo.list_prerequisites(db, r.id)
        prereq_list = []
        for p in prereqs:
            upload = await sponsor_repo.get_bid_prerequisite_upload(db, r.bid_id, p.id)
            prereq_list.append({
                "id": p.id,
                "name": p.name,
                "is_required": p.is_required,
                "requires_document": p.requires_document,
                "upload_status": upload.status.value if upload else None,
            })

        payment = await sponsor_repo.get_payment_by_bid(db, r.bid_id)

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

    ticket = await sponsor_repo.get_sponsor_ticket_with_delegates(db, ticket_id)
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
        await sponsor_repo.flush(db)

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
