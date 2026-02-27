"""
Event tickets: tiers CRUD, price, purchase, refund, scan, receipts, stats, waitlist, capacity.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, select

from app.dependencies import CurrentUser, DbSession, ReadDbSession, require_role
from app.models.funding import Funding, FundingStatus, PledgeSpotReservation
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.user import User, UserRole
from app.models.venue import Venue
from app.schemas import (
    PurchaseGroupReceiptResponse,
    ScanTicketBody,
    ScanTicketResponse,
    TicketPricePreviewResponse,
    TicketPurchaseBody,
    TicketReceiptResponse,
    TicketSaleResponse,
    TicketSalesStatsResponse,
    TicketSummaryItem,
    TicketTierCreate,
    TicketTierResponse,
    TicketTierUpdate,
)
from app.core.exceptions import ForbiddenError, NotFoundError
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import ticket as ticket_service
from app.services import platform_settings as settings_svc
from app.services import notification_service as notif_svc
from app.services.ticket_crypto import encrypt_ticket_qr, decrypt_ticket_qr
from app.worker.redis_pool import enqueue as arq_enqueue
from app.models.notification import NotificationType
from app.rate_limit import limiter, dynamic_limit
from app.api.v1.events._helpers import safe_display_name

router = APIRouter()


def _ticket_sale_to_response(sale) -> TicketSaleResponse:
    """Build TicketSaleResponse from a TicketSale."""
    scanned_by_name = None
    if getattr(sale, "scanned_by", None) and sale.scanned_by:
        scanned_by_name = safe_display_name(sale.scanned_by)
    attendee_name = None
    if getattr(sale, "user", None) and sale.user:
        attendee_name = safe_display_name(sale.user)
    return TicketSaleResponse(
        id=sale.id,
        event_id=sale.event_id,
        user_id=sale.user_id,
        ticket_tier_id=sale.ticket_tier_id,
        purchase_group_id=getattr(sale, "purchase_group_id", None),
        ticket_code=sale.ticket_code,
        receipt_number=getattr(sale, "receipt_number", None),
        tier_name=sale.ticket_tier.name if sale.ticket_tier else None,
        event_title=sale.event.title if sale.event else None,
        attendee_display_name=attendee_name,
        amount_paid_cents=sale.amount_paid_cents,
        discount_applied_cents=sale.discount_applied_cents,
        commission_cents=getattr(sale, "commission_cents", 0) or 0,
        net_to_organizer_cents=getattr(sale, "net_to_organizer_cents", 0) or 0,
        extra_perks=sale.extra_perks,
        status=sale.status.value,
        scanned_at=sale.scanned_at,
        scanned_by_id=sale.scanned_by_id,
        scanned_by_display_name=scanned_by_name,
        encrypted_qr_payload=encrypt_ticket_qr(sale.ticket_code, sale.event_id, sale.id),
        created_at=sale.created_at,
    )


@router.get("/{event_id}/ticket-tiers", response_model=list[TicketTierResponse])
async def list_ticket_tiers(event_id: int, db: DbSession):
    """List ticket tiers for an event (public), with sold and reserved counts."""
    tiers = await ticket_service.list_tiers(db, event_id=event_id)
    tier_ids = [t.id for t in tiers]
    sold_counts: dict[int, int] = {}
    reserved_counts: dict[int, int] = {}

    if tier_ids:
        sold_rows = (await db.execute(
            select(TicketSale.ticket_tier_id, func.count())
            .where(
                TicketSale.ticket_tier_id.in_(tier_ids),
                TicketSale.status == TicketSaleStatus.purchased,
            )
            .group_by(TicketSale.ticket_tier_id)
        )).all()
        sold_counts = {r[0]: r[1] for r in sold_rows}

        buyers_sub = (
            select(TicketSale.user_id)
            .where(
                TicketSale.ticket_tier_id == PledgeSpotReservation.ticket_tier_id,
                TicketSale.event_id == event_id,
                TicketSale.status == TicketSaleStatus.purchased,
            )
            .correlate(PledgeSpotReservation)
        )
        res_rows = (await db.execute(
            select(PledgeSpotReservation.ticket_tier_id, func.coalesce(func.sum(PledgeSpotReservation.spots), 0))
            .join(Funding, Funding.id == PledgeSpotReservation.funding_id)
            .where(
                PledgeSpotReservation.ticket_tier_id.in_(tier_ids),
                Funding.event_id == event_id,
                Funding.status.in_([FundingStatus.pledged, FundingStatus.collected]),
                ~Funding.user_id.in_(buyers_sub),
            )
            .group_by(PledgeSpotReservation.ticket_tier_id)
        )).all()
        reserved_counts = {r[0]: int(r[1]) for r in res_rows}

    return [
        TicketTierResponse(
            id=t.id,
            event_id=t.event_id,
            name=t.name,
            description=t.description,
            price_cents=t.price_cents,
            max_reserved_spots=t.max_reserved_spots,
            tickets_sold=sold_counts.get(t.id, 0),
            spots_reserved=reserved_counts.get(t.id, 0),
            display_order=t.display_order,
        )
        for t in tiers
    ]


@router.post("/{event_id}/ticket-tiers", response_model=TicketTierResponse)
async def create_ticket_tier(
    event_id: int,
    body: TicketTierCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create a ticket tier (organizer/admin)."""
    tier = await ticket_service.create_tier(
        db, event_id=event_id, user=current_user,
        name=body.name, description=body.description,
        price_cents=body.price_cents,
        max_reserved_spots=body.max_reserved_spots,
        display_order=body.display_order,
    )
    return TicketTierResponse.model_validate(tier)


@router.patch("/{event_id}/ticket-tiers/{tier_id}", response_model=TicketTierResponse)
async def update_ticket_tier(
    event_id: int,
    tier_id: int,
    body: TicketTierUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update a ticket tier (organizer/admin)."""
    tier = await ticket_service.get_tier_or_404(db, event_id=event_id, tier_id=tier_id)
    tier = await ticket_service.update_tier(
        db, tier, current_user,
        name=body.name, description=body.description,
        price_cents=body.price_cents,
        max_reserved_spots=body.max_reserved_spots,
        display_order=body.display_order,
    )
    return TicketTierResponse.model_validate(tier)


@router.delete("/{event_id}/ticket-tiers/{tier_id}")
async def delete_ticket_tier(
    event_id: int,
    tier_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete a ticket tier (organizer/admin)."""
    tier = await ticket_service.get_tier_or_404(db, event_id=event_id, tier_id=tier_id)
    await ticket_service.delete_tier(db, tier, current_user)
    return {"ok": True}


@router.get("/{event_id}/ticket-price", response_model=TicketPricePreviewResponse)
async def get_ticket_price(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
    ticket_tier_id: int = Query(..., description="Ticket tier id", alias="ticket_tier_id"),
):
    """Preview ticket price for current user (with discounts + commission)."""
    info = await ticket_service.compute_ticket_price(
        db, event_id=event_id, user_id=current_user.id, tier_id=ticket_tier_id
    )
    final = info["final_price_cents"]
    commission_pct = await settings_svc.get_int(db, "ticket_commission_percent")
    commission = final * commission_pct // 100 if final > 0 else 0
    info["commission_cents"] = commission
    info["net_to_organizer_cents"] = final - commission
    info["ticket_commission_percent"] = commission_pct
    return TicketPricePreviewResponse(**info)


@router.post("/{event_id}/purchase-ticket", response_model=list[TicketSaleResponse])
@limiter.limit(dynamic_limit("ticket_purchase", "15/minute"))
async def purchase_ticket(
    request: Request,
    event_id: int,
    body: TicketPurchaseBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Purchase one or more tickets (customer, must be registered)."""
    sales = await ticket_service.purchase_ticket(
        db, event_id=event_id, user=current_user,
        tier_id=body.tier_id, quantity=body.quantity, extra_perks=body.extra_perks,
    )
    if sales:
        first = sales[0]
        event = first.event
        tier = first.ticket_tier
        await arq_enqueue(
            "send_ticket_purchased_email",
            buyer_email=current_user.email,
            buyer_name=current_user.display_name or "",
            event_title=event.title if event else f"Event #{event_id}",
            tier_name=tier.name if tier else "General",
            ticket_code=first.ticket_code,
            receipt_number=first.receipt_number or "",
            amount_cents=first.amount_paid_cents,
            quantity=len(sales),
            event_date=event.start_time if event else None,
            discount_cents=first.discount_applied_cents,
            commission_cents=getattr(first, "commission_cents", 0) or 0,
        )
        await notif_svc.create_notification(
            db, user_id=current_user.id,
            type=NotificationType.ticket_purchased,
            title="Ticket Purchased",
            message=f"You purchased {len(sales)} ticket(s) for \"{event.title if event else 'the event'}\".",
            data={"event_id": event_id, "ticket_sale_id": first.id},
        )
    return [_ticket_sale_to_response(s) for s in sales]


@router.post("/{event_id}/tickets/{ticket_id}/refund", response_model=TicketSaleResponse)
@limiter.limit(dynamic_limit("payment_action", "10/minute"))
async def request_ticket_refund(
    request: Request,
    event_id: int,
    ticket_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Customer requests a refund for a purchased ticket."""
    sale = await ticket_service.request_refund(
        db, event_id=event_id, ticket_sale_id=ticket_id, user=current_user,
    )
    event = sale.event
    if event:
        await notif_svc.create_notification(
            db, user_id=event.organizer_id,
            type=NotificationType.refund_issued,
            title="Refund Requested",
            message=f"{safe_display_name(current_user)} requested a ticket refund for \"{event.title}\".",
            data={"event_id": event_id, "ticket_sale_id": ticket_id},
        )
    return _ticket_sale_to_response(sale)


@router.get("/{event_id}/refund-requests", response_model=list[TicketSaleResponse])
async def list_refund_requests(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List tickets with pending refund requests (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot manage refunds for this event")
    sales = await ticket_service.list_refund_requests(db, event_id=event_id)
    return [_ticket_sale_to_response(s) for s in sales]


@router.post("/{event_id}/tickets/{ticket_id}/approve-refund", response_model=TicketSaleResponse)
async def approve_ticket_refund(
    event_id: int,
    ticket_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Organizer approves a refund request."""
    sale = await ticket_service.approve_refund(
        db, event_id=event_id, ticket_sale_id=ticket_id, user=current_user,
    )
    if sale.user_id:
        await notif_svc.create_notification(
            db, user_id=sale.user_id,
            type=NotificationType.refund_issued,
            title="Refund Approved",
            message=f"Your ticket refund of ${sale.amount_paid_cents / 100:.2f} has been approved.",
            data={"event_id": event_id, "ticket_sale_id": ticket_id},
        )
        buyer = sale.user
        if buyer and buyer.email:
            event = sale.event
            tier = sale.ticket_tier
            await arq_enqueue(
                "send_ticket_refund_approved_email",
                buyer_email=buyer.email,
                buyer_name=buyer.display_name or "",
                event_title=event.title if event else f"Event #{event_id}",
                tier_name=tier.name if tier else "General",
                amount_cents=sale.amount_paid_cents,
                receipt_number=sale.receipt_number or "",
            )
    return _ticket_sale_to_response(sale)


@router.post("/{event_id}/tickets/{ticket_id}/reject-refund", response_model=TicketSaleResponse)
async def reject_ticket_refund(
    event_id: int,
    ticket_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Organizer rejects a refund request."""
    sale = await ticket_service.reject_refund(
        db, event_id=event_id, ticket_sale_id=ticket_id, user=current_user,
    )
    if sale.user_id:
        await notif_svc.create_notification(
            db, user_id=sale.user_id,
            type=NotificationType.refund_issued,
            title="Refund Rejected",
            message=f"Your ticket refund request for \"{sale.event.title if sale.event else 'the event'}\" was rejected.",
            data={"event_id": event_id, "ticket_sale_id": ticket_id},
        )
    return _ticket_sale_to_response(sale)


@router.post("/{event_id}/scan-ticket", response_model=ScanTicketResponse)
@limiter.limit(dynamic_limit("qr_scan", "30/minute"))
async def scan_ticket(
    request: Request,
    event_id: int,
    body: ScanTicketBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Scan a ticket by QR code (organizer/admin)."""
    ticket_code: str | None = None
    if body.encrypted_payload:
        try:
            data = decrypt_ticket_qr(body.encrypted_payload)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=f"Invalid encrypted ticket: {exc}")
        ticket_code = data["tc"]
        payload_event_id = data.get("eid")
        if payload_event_id is not None and int(payload_event_id) != event_id:
            raise HTTPException(status_code=400, detail="Ticket belongs to a different event")
    else:
        ticket_code = body.ticket_code

    sale, already_scanned = await ticket_service.scan_ticket(
        db, event_id=event_id, ticket_code=ticket_code, scanned_by_user=current_user,
    )
    return ScanTicketResponse(already_scanned=already_scanned, ticket=_ticket_sale_to_response(sale))


@router.get("/{event_id}/tickets/{sale_id}/receipt", response_model=TicketReceiptResponse)
async def get_ticket_receipt(
    event_id: int,
    sale_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Get full receipt for a ticket purchase."""
    sale = await ticket_service.get_ticket_receipt(db, sale_id=sale_id)
    if sale.event_id != event_id:
        raise NotFoundError("TicketSale", sale_id)
    if current_user.role == UserRole.customer:
        if sale.user_id != current_user.id:
            raise ForbiddenError("You can only view your own ticket receipts")
    else:
        event = await event_service.get_or_404(db, event_id)
        if not await event_service.user_can_edit_event(db, event, current_user):
            raise ForbiddenError("You cannot view receipts for this event")

    venue_name = None
    venue_address = None
    if sale.event and sale.event.venue_id:
        venue = (await db.execute(select(Venue).where(Venue.id == sale.event.venue_id))).scalar_one_or_none()
        if venue:
            venue_name = venue.name
            parts = [p for p in [venue.address, venue.city, venue.province] if p]
            venue_address = ", ".join(parts) if parts else None

    organizer_name = None
    organizer_email = None
    organizer_phone = None
    if sale.event and sale.event.organizer_id:
        from app.models.user import User as UserModel
        organizer = (await db.execute(select(UserModel).where(UserModel.id == sale.event.organizer_id))).scalar_one_or_none()
        if organizer:
            organizer_name = organizer.display_name
            organizer_email = organizer.email
            organizer_phone = organizer.phone

    return TicketReceiptResponse(
        sale_id=sale.id,
        user_id=sale.user_id,
        receipt_number=sale.receipt_number or f"RCP-{sale.event_id}-{sale.id}",
        ticket_code=sale.ticket_code,
        status=sale.status.value,
        attendee_name=sale.user.display_name if sale.user else None,
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
        subtotal_cents=getattr(sale, "subtotal_cents", 0) or 0,
        tax_cents=getattr(sale, "tax_cents", 0) or 0,
        tax_rate=getattr(sale, "tax_rate", 0.0) or 0.0,
        tax_jurisdiction=getattr(sale, "tax_jurisdiction", None) or None,
        extra_perks=sale.extra_perks,
        encrypted_qr_payload=encrypt_ticket_qr(sale.ticket_code, sale.event_id, sale.id),
        purchased_at=sale.created_at,
        scanned_at=sale.scanned_at,
    )


@router.get("/{event_id}/purchase-group/{group_id}/receipt", response_model=PurchaseGroupReceiptResponse)
async def get_purchase_group_receipt(
    event_id: int,
    group_id: str,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Get aggregated receipt for a multi-ticket purchase group."""
    sales = await ticket_service.get_purchase_group_tickets(db, purchase_group_id=group_id)
    if not sales or sales[0].event_id != event_id:
        raise NotFoundError("PurchaseGroup", group_id)
    if current_user.role == UserRole.customer:
        if sales[0].user_id != current_user.id:
            raise ForbiddenError("You can only view your own purchase groups")
    else:
        event = await event_service.get_or_404(db, event_id)
        if not await event_service.user_can_edit_event(db, event, current_user):
            raise ForbiddenError("You cannot view purchase groups for this event")

    sale0 = sales[0]
    venue_name = None
    venue_address = None
    if sale0.event and sale0.event.venue_id:
        venue = (await db.execute(select(Venue).where(Venue.id == sale0.event.venue_id))).scalar_one_or_none()
        if venue:
            venue_name = venue.name
            parts = [p for p in [venue.address, venue.city, venue.province] if p]
            venue_address = ", ".join(parts) if parts else None

    organizer_name = None
    organizer_email = None
    organizer_phone = None
    if sale0.event and sale0.event.organizer_id:
        from app.models.user import User as UserModel
        organizer = (await db.execute(select(UserModel).where(UserModel.id == sale0.event.organizer_id))).scalar_one_or_none()
        if organizer:
            organizer_name = organizer.display_name
            organizer_email = organizer.email
            organizer_phone = organizer.phone

    tickets = [
        TicketSummaryItem(
            sale_id=s.id,
            ticket_code=s.ticket_code,
            receipt_number=s.receipt_number,
            encrypted_qr_payload=encrypt_ticket_qr(s.ticket_code, s.event_id, s.id),
            status=s.status.value,
            scanned_at=s.scanned_at,
        )
        for s in sales
    ]

    return PurchaseGroupReceiptResponse(
        purchase_group_id=group_id,
        event_id=event_id,
        event_title=sale0.event.title if sale0.event else "Unknown Event",
        event_start_time=sale0.event.start_time if sale0.event else None,
        event_end_time=sale0.event.end_time if sale0.event else None,
        organizer_name=organizer_name,
        organizer_email=organizer_email,
        organizer_phone=organizer_phone,
        venue_name=venue_name,
        venue_address=venue_address,
        attendee_name=sale0.user.display_name if sale0.user else None,
        tier_name=sale0.ticket_tier.name if sale0.ticket_tier else "Unknown",
        tier_price_cents=sale0.ticket_tier.price_cents if sale0.ticket_tier else 0,
        quantity=len(sales),
        total_amount_paid_cents=sum(s.amount_paid_cents for s in sales),
        total_discount_applied_cents=sum(s.discount_applied_cents for s in sales),
        total_commission_cents=sum(getattr(s, "commission_cents", 0) or 0 for s in sales),
        total_net_to_organizer_cents=sum(getattr(s, "net_to_organizer_cents", 0) or 0 for s in sales),
        total_subtotal_cents=sum(getattr(s, "subtotal_cents", 0) or 0 for s in sales),
        total_tax_cents=sum(getattr(s, "tax_cents", 0) or 0 for s in sales),
        tax_rate=getattr(sale0, "tax_rate", 0.0) or 0.0,
        tax_jurisdiction=getattr(sale0, "tax_jurisdiction", None) or None,
        tickets=tickets,
        purchased_at=sale0.created_at,
    )


@router.get("/{event_id}/ticket-sales-stats", response_model=TicketSalesStatsResponse)
async def get_ticket_sales_stats(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Get ticket sold vs scanned stats for an event."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view stats for this event")
    stats = await ticket_service.get_ticket_sales_stats(db, event_id=event_id)
    return TicketSalesStatsResponse(**stats)


@router.get("/{event_id}/ticket-sales", response_model=list[TicketSaleResponse])
async def list_event_ticket_sales(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List ticket sales for event (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view ticket sales for this event")
    sales = await ticket_service.list_event_ticket_sales(db, event_id=event_id, offset=offset, limit=limit)
    return [_ticket_sale_to_response(s) for s in sales]


@router.get("/{event_id}/scanned-tickets", response_model=list[TicketSaleResponse])
async def list_event_scanned_tickets(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List only scanned tickets for event (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view scanned tickets for this event")
    sales = await ticket_service.list_event_scanned_ticket_sales(db, event_id=event_id, offset=offset, limit=limit)
    return [_ticket_sale_to_response(s) for s in sales]


@router.get("/{event_id}/waitlisted-tickets", response_model=list[TicketSaleResponse])
async def list_event_waitlisted_tickets(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List waitlisted tickets for event (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view waitlisted tickets for this event")
    sales = await ticket_service.list_event_waitlisted_tickets(db, event_id=event_id)
    return [_ticket_sale_to_response(s) for s in sales]


@router.post("/{event_id}/waitlisted-tickets/{ticket_id}/approve", response_model=TicketSaleResponse)
async def approve_waitlisted_ticket(
    event_id: int,
    ticket_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Approve a waitlisted ticket → purchased (organizer/admin)."""
    sale = await ticket_service.approve_waitlisted_ticket(
        db, event_id=event_id, ticket_sale_id=ticket_id, user=current_user,
    )
    await notif_svc.create_notification(
        db, user_id=sale.user_id,
        type=NotificationType.ticket_waitlist_approved,
        title="Ticket Approved",
        message="Your waitlisted ticket has been approved!",
        data={"event_id": event_id, "ticket_sale_id": ticket_id},
    )
    buyer = sale.user
    if buyer and buyer.email:
        event = sale.event
        tier = sale.ticket_tier
        await arq_enqueue(
            "send_waitlist_approved_email",
            buyer_email=buyer.email,
            buyer_name=buyer.display_name or "",
            event_title=event.title if event else f"Event #{event_id}",
            tier_name=tier.name if tier else "General",
            amount_cents=sale.amount_paid_cents,
            ticket_code=sale.ticket_code,
            event_date=event.start_time if event else None,
        )
    return _ticket_sale_to_response(sale)


@router.post("/{event_id}/waitlisted-tickets/{ticket_id}/reject", response_model=TicketSaleResponse)
async def reject_waitlisted_ticket(
    event_id: int,
    ticket_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Reject a waitlisted ticket → cancelled (organizer/admin)."""
    sale = await ticket_service.reject_waitlisted_ticket(
        db, event_id=event_id, ticket_sale_id=ticket_id, user=current_user,
    )
    buyer = sale.user
    event = sale.event
    tier = sale.ticket_tier
    if buyer and buyer.email:
        await arq_enqueue(
            "send_waitlist_rejected_email",
            buyer_email=buyer.email,
            buyer_name=buyer.display_name or "",
            event_title=event.title if event else f"Event #{event_id}",
            tier_name=tier.name if tier else "General",
            amount_cents=sale.amount_paid_cents,
        )
    if sale.user_id:
        await notif_svc.create_notification(
            db, user_id=sale.user_id,
        type=NotificationType.ticket_waitlist_rejected,
        title="Ticket Rejected",
        message="Your waitlisted ticket was not approved.",
        data={"event_id": event_id, "ticket_sale_id": ticket_id},
        )
    return _ticket_sale_to_response(sale)


@router.get("/{event_id}/capacity-info")
async def get_capacity_info(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Capacity breakdown for waitlist management (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    tickets_sold = int((await db.execute(
        select(func.count()).where(TicketSale.event_id == event_id, TicketSale.status == TicketSaleStatus.purchased)
    )).scalar_one())
    total_reserved = await funding_service.get_total_reserved_spots(db, event_id=event_id)
    return {
        "max_capacity": event.max_capacity,
        "tickets_sold": tickets_sold,
        "total_reserved_spots": total_reserved,
        "occupied": tickets_sold + total_reserved,
        "available": max(0, event.max_capacity - tickets_sold - total_reserved),
        "registration_count": event.registration_count,
    }
