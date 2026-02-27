"""Sponsor ticket endpoints."""
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature
from app.logger import get_logger, log_step
from app.models.sponsor import SponsorTicket, SponsorDelegate
from app.rate_limit import limiter, dynamic_limit
from app.schemas.sponsor import SponsorTicketResponse
from app.services import sponsor as sponsor_svc

logger = get_logger("api.sponsors.tickets")
router = APIRouter(dependencies=[Depends(require_feature("feature_sponsors_enabled"))])


@router.get(
    "/me/sponsor-tickets",
    response_model=list[SponsorTicketResponse],
)
async def list_my_sponsor_tickets(db: ReadDbSession, current_user: CurrentUser):
    tickets = await sponsor_svc.list_sponsor_tickets(db, current_user.id)
    result = []
    for t in tickets:
        cats = await sponsor_svc.get_won_categories(db, t.event_id, current_user.id)
        event = t.event
        venue = event.venue if event else None
        result.append({
            "id": t.id,
            "event_id": t.event_id,
            "sponsor_user_id": t.sponsor_user_id,
            "receipt_number": t.receipt_number,
            "encrypted_qr_payload": t.qr_data_encrypted,
            "scanned_at": t.scanned_at.isoformat() if t.scanned_at else None,
            "created_at": t.created_at.isoformat() if t.created_at else None,
            "categories": cats,
            "category_names": [c["name"] for c in cats],
            "category_count": len(cats),
            "event_title": event.title if event else None,
            "event_status": event.status.value if event else None,
            "event_start_time": event.start_time.isoformat() if event and event.start_time else None,
            "venue_name": venue.name if venue else None,
            "venue_address": venue.address if venue else None,
            "venue_city": venue.city if venue else None,
            "scan_count": t.scan_count or 0,
        })
    return result


@router.post("/events/{event_id}/scan-sponsor")
@limiter.limit(dynamic_limit("qr_scan", "30/minute"))
async def scan_sponsor_ticket(
    request: Request,
    event_id: int,
    body: dict,
    db: DbSession,
    current_user: CurrentUser,
):
    from app.services import event as event_service
    from app.core.exceptions import ForbiddenError as Forbidden

    log_step(logger, "Scanning sponsor ticket", event_id=event_id, user_id=current_user.id)
    logger.debug("Scan request", extra={"payload_length": len(body.get("encrypted_payload", ""))})
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_scan_tickets(db, event, current_user):
        logger.warning("User cannot scan tickets for event", extra={"event_id": event_id, "user_id": current_user.id})
        raise Forbidden("You cannot scan tickets for this event")
    payload = body.get("encrypted_payload", "")
    if not payload:
        logger.warning("Missing encrypted_payload in scan request", extra={"event_id": event_id, "user_id": current_user.id})
        raise HTTPException(status_code=400, detail="encrypted_payload required")
    result = await sponsor_svc.scan_sponsor_ticket(db, event_id, payload)
    await db.commit()
    return result


@router.get("/events/{event_id}/scanned-sponsor-tickets")
async def scanned_sponsor_tickets(
    event_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    from app.services import event as event_service
    from app.core.exceptions import ForbiddenError as Forbidden

    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_scan_tickets(db, event, current_user):
        logger.warning("User cannot view scanned tickets", extra={"event_id": event_id, "user_id": current_user.id})
        raise Forbidden("You cannot view scanned tickets for this event")

    q = (
        select(SponsorTicket)
        .options(selectinload(SponsorTicket.delegates))
        .where(SponsorTicket.event_id == event_id, SponsorTicket.scan_count > 0)
        .order_by(SponsorTicket.scanned_at.desc())
    )
    tickets = list((await db.execute(q)).scalars().all())

    results = []
    for t in tickets:
        profile = await sponsor_svc.get_profile(db, t.sponsor_user_id)
        delegates = t.delegates or []
        results.append({
            "id": t.id,
            "event_id": t.event_id,
            "receipt_number": t.receipt_number,
            "company_name": profile.company_name if profile else "Unknown",
            "contact_name": profile.contact_name if profile else "",
            "scan_count": t.scan_count or 0,
            "scanned_at": t.scanned_at.isoformat() if t.scanned_at else None,
            "total_delegates": len(delegates),
            "checked_in_count": sum(1 for d in delegates if d.checked_in),
            "delegates": [
                {
                    "id": d.id,
                    "name": d.name,
                    "checked_in": d.checked_in,
                    "checked_in_at": d.checked_in_at.isoformat() if d.checked_in_at else None,
                }
                for d in sorted(delegates, key=lambda d: (d.checked_in, d.created_at))
            ],
        })
    return results
