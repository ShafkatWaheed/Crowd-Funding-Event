"""
Users: profile (GET/PATCH /me), my pledges (GET /me/pledges), my tickets (GET /me/tickets), my events (GET /me/events).
"""
from fastapi import APIRouter, Depends

from app.dependencies import CurrentUser, DbSession, require_role
from app.models.user import User, UserRole
from app.schemas import EventResponse, MeResponse, MeUpdate, MyPledgeItem, PledgeReceiptResponse, TicketReceiptResponse, TicketSaleResponse
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
            reserved_spots=p.reserved_spots,
            receipt_number=p.receipt_number,
            status=p.status.value,
            created_at=p.created_at,
        )
        for p in pledges
    ]


@router.get("/pledges/{pledge_id}/receipt", response_model=PledgeReceiptResponse)
async def get_my_pledge_receipt(
    pledge_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Get a pledge receipt for the current user."""
    from sqlalchemy import select
    from app.models.funding import Funding
    pledge = (await db.execute(
        select(Funding).where(Funding.id == pledge_id, Funding.user_id == current_user.id)
    )).scalar_one_or_none()
    if not pledge:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Pledge", pledge_id)
    event = await event_service.get_or_404(db, pledge.event_id)
    from app.services import platform_settings as settings_svc
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")
    return PledgeReceiptResponse(
        id=pledge.id,
        receipt_number=pledge.receipt_number,
        event_id=pledge.event_id,
        event_title=event.title,
        user_id=pledge.user_id,
        amount_cents=pledge.amount_cents,
        reserved_spots=pledge.reserved_spots,
        platform_cut_cents=pledge.platform_cut_cents,
        net_to_organizer_cents=pledge.net_to_organizer_cents,
        funding_commission_percent=funding_pct,
        status=pledge.status.value,
        created_at=pledge.created_at,
    )


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
            receipt_number=getattr(s, "receipt_number", None),
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


@router.get("/tickets/{sale_id}/receipt", response_model=TicketReceiptResponse)
async def get_my_ticket_receipt(
    sale_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Get receipt for a specific ticket the current user purchased."""
    sale = await ticket_service.get_ticket_receipt(db, sale_id=sale_id, user_id=current_user.id)

    # Load venue info
    venue_name = None
    venue_address = None
    if sale.event and sale.event.venue_id:
        from app.models.venue import Venue
        from sqlalchemy import select as sel
        venue = (await db.execute(sel(Venue).where(Venue.id == sale.event.venue_id))).scalar_one_or_none()
        if venue:
            venue_name = venue.name
            parts = [p for p in [venue.address, venue.city, venue.province] if p]
            venue_address = ", ".join(parts) if parts else None

    # Load organizer info
    organizer_name = None
    organizer_email = None
    organizer_phone = None
    if sale.event and sale.event.organizer_id:
        from sqlalchemy import select as sel2
        organizer = (await db.execute(sel2(User).where(User.id == sale.event.organizer_id))).scalar_one_or_none()
        if organizer:
            organizer_name = organizer.display_name or organizer.email
            organizer_email = organizer.email
            organizer_phone = organizer.phone

    return TicketReceiptResponse(
        receipt_number=sale.receipt_number or f"RCP-{sale.event_id}-{sale.id}",
        ticket_code=sale.ticket_code,
        status=sale.status.value,
        attendee_name=(sale.user.display_name or sale.user.email) if sale.user else None,
        attendee_email=sale.user.email if sale.user else None,
        event_id=sale.event_id,
        event_title=sale.event.title if sale.event else "Unknown Event",
        event_start_time=sale.event.start_time if sale.event else None,
        event_end_time=sale.event.end_time if sale.event else None,
        organizer_name=organizer_name,
        organizer_email=organizer_email,
        organizer_phone=organizer_phone,
        venue_name=venue_name,
        venue_address=venue_address,
        tier_name=sale.ticket_tier.name if sale.ticket_tier else "Unknown",
        tier_price_cents=sale.ticket_tier.price_cents if sale.ticket_tier else 0,
        amount_paid_cents=sale.amount_paid_cents,
        discount_applied_cents=sale.discount_applied_cents,
        commission_cents=getattr(sale, "commission_cents", 0) or 0,
        net_to_organizer_cents=getattr(sale, "net_to_organizer_cents", 0) or 0,
        extra_perks=sale.extra_perks,
        purchased_at=sale.created_at,
        scanned_at=sale.scanned_at,
    )


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
