"""
Users: profile (GET/PATCH /me), my pledges (GET /me/pledges), my tickets (GET /me/tickets), my events (GET /me/events).
"""
from fastapi import APIRouter, Depends

from app.dependencies import CurrentUser, DbSession, require_role
from app.models.user import User, UserRole
from app.schemas import EventResponse, MeResponse, MeUpdate, MyPledgeItem, TicketSaleResponse
from app.api.v1.events import _event_to_response
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import ticket as ticket_service

router = APIRouter()


@router.get("", response_model=MeResponse)
async def get_me(current_user: CurrentUser):
    """Current user profile."""
    return MeResponse(
        id=current_user.id,
        email=current_user.email,
        display_name=current_user.display_name,
        phone=current_user.phone,
        role=current_user.role.value,
    )


@router.patch("", response_model=MeResponse)
async def update_me(
    body: MeUpdate,
    current_user: CurrentUser,
    db: DbSession,
):
    """Update current user profile."""
    if body.display_name is not None:
        current_user.display_name = body.display_name
    if body.phone is not None:
        current_user.phone = body.phone
    await db.flush()
    await db.refresh(current_user)
    return MeResponse(
        id=current_user.id,
        email=current_user.email,
        display_name=current_user.display_name,
        phone=current_user.phone,
        role=current_user.role.value,
    )


@router.get("/pledges", response_model=list[MyPledgeItem])
async def get_my_pledges(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """List events the current user has pledged to (customer only)."""
    pledges = await funding_service.list_pledges_by_user(db, user_id=current_user.id)
    return [
        MyPledgeItem(
            id=p.id,
            event_id=p.event_id,
            event_title=p.event.title if p.event else "",
            amount_cents=p.amount_cents,
            status=p.status.value,
            created_at=p.created_at,
        )
        for p in pledges
    ]


@router.get("/tickets", response_model=list[TicketSaleResponse])
async def get_my_tickets(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """List tickets the current user has purchased (customer only). Includes ticket_code for QR and scanned_at (already scanned)."""
    sales = await ticket_service.list_my_tickets(db, user_id=current_user.id)
    return [
        TicketSaleResponse(
            id=s.id,
            event_id=s.event_id,
            user_id=s.user_id,
            ticket_tier_id=s.ticket_tier_id,
            ticket_code=s.ticket_code,
            tier_name=s.ticket_tier.name if s.ticket_tier else None,
            event_title=s.event.title if s.event else None,
            attendee_display_name=(s.user.display_name or s.user.email) if s.user else None,
            amount_paid_cents=s.amount_paid_cents,
            discount_applied_cents=s.discount_applied_cents,
            extra_perks=s.extra_perks,
            status=s.status.value,
            scanned_at=s.scanned_at,
            scanned_by_id=s.scanned_by_id,
            scanned_by_display_name=None,
            created_at=s.created_at,
        )
        for s in sales
    ]


@router.get("/events", response_model=list[EventResponse])
async def get_my_events(
    db: DbSession,
    current_user: CurrentUser,
):
    """Events the current user is registered to (includes cancelled events so the user can see cancellation reasons)."""
    events = await event_service.get_my_registered_events(db, user_id=current_user.id)
    return [_event_to_response(e) for e in events]


@router.get("/customers")
async def list_my_customers(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List all customers who attended events organized by the current user, with event counts."""
    return await event_service.list_organizer_customers(db, organizer_id=current_user.id)
