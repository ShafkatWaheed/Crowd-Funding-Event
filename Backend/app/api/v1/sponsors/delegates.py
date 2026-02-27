"""Sponsor delegate endpoints: CRUD + check-in."""
from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature
from app.rate_limit import limiter, dynamic_limit
from app.services import sponsor as sponsor_svc
from app.services.platform_settings import get_int


router = APIRouter(dependencies=[Depends(require_feature("feature_sponsors_enabled"))])


class AddDelegateBody(BaseModel):
    name: str
    email: str | None = None
    phone: str | None = None


@router.get("/me/sponsor-tickets/{ticket_id}/delegates")
async def list_delegates(
    ticket_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    delegates = await sponsor_svc.list_delegates(db, ticket_id, current_user.id)
    return [
        {
            "id": d.id,
            "sponsor_ticket_id": d.sponsor_ticket_id,
            "name": d.name,
            "email": d.email,
            "phone": d.phone,
            "checked_in": d.checked_in,
            "checked_in_at": d.checked_in_at.isoformat() if d.checked_in_at else None,
            "created_at": d.created_at.isoformat() if d.created_at else None,
        }
        for d in delegates
    ]


@router.post("/me/sponsor-tickets/{ticket_id}/delegates")
async def add_delegate(
    ticket_id: int,
    body: AddDelegateBody,
    db: DbSession,
    current_user: CurrentUser,
):
    max_delegates = await get_int(db, "max_sponsor_delegates_per_ticket")
    delegate = await sponsor_svc.add_delegate(
        db,
        ticket_id,
        current_user.id,
        name=body.name,
        email=body.email,
        phone=body.phone,
        max_delegates=max_delegates,
    )
    await db.commit()
    return {
        "id": delegate.id,
        "sponsor_ticket_id": delegate.sponsor_ticket_id,
        "name": delegate.name,
        "email": delegate.email,
        "phone": delegate.phone,
        "checked_in": delegate.checked_in,
        "checked_in_at": None,
        "created_at": delegate.created_at.isoformat() if delegate.created_at else None,
    }


@router.delete("/me/sponsor-tickets/{ticket_id}/delegates/{delegate_id}")
async def remove_delegate(
    ticket_id: int,
    delegate_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    await sponsor_svc.remove_delegate(db, delegate_id, current_user.id)
    await db.commit()
    return {"ok": True}


@router.post("/events/{event_id}/sponsor-delegates/{delegate_id}/check-in")
@limiter.limit(dynamic_limit("qr_scan", "30/minute"))
async def check_in_delegate(
    request: Request,
    event_id: int,
    delegate_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    from app.services import event as event_service
    from app.core.exceptions import ForbiddenError as Forbidden

    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_scan_tickets(db, event, current_user):
        raise Forbidden("You cannot scan tickets for this event")

    result = await sponsor_svc.check_in_delegate(db, delegate_id)
    await db.commit()
    return result
