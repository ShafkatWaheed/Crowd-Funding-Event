"""Sponsor ticket endpoints."""
from fastapi import APIRouter, Depends, HTTPException, Request

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature
from app.rate_limit import limiter, dynamic_limit
from app.schemas.sponsor import SponsorTicketResponse
from app.services import sponsor as sponsor_svc

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
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_scan_tickets(db, event, current_user):
        raise Forbidden("You cannot scan tickets for this event")
    payload = body.get("encrypted_payload", "")
    if not payload:
        raise HTTPException(status_code=400, detail="encrypted_payload required")
    result = await sponsor_svc.scan_sponsor_ticket(db, event_id, payload)
    await db.commit()
    return result
