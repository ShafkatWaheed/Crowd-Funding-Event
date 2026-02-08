"""
Events: CRUD, list (filters), pledge, register, registrations.
"""
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response

from app.dependencies import DbSession, require_role
from app.models.event import Event, RegistrationType
from app.models.user import User, UserRole
from app.schemas import (
    AddEventOrganizerBody,
    EventCreate,
    EventOrganizerItem,
    EventResponse,
    EventUpdate,
    EventVenueInfo,
    ExtendFundingBody,
    FundingSummaryResponse,
    PledgeBody,
    PledgeResponse,
    RegistrationDecisionBody,
    RegistrationResponse,
    ScanTicketBody,
    ScanTicketResponse,
    TicketPricePreviewResponse,
    TicketPurchaseBody,
    TicketSaleResponse,
    TicketTierCreate,
    TicketTierResponse,
    TicketTierUpdate,
    UnregisterResponse,
    UserDiscountBody,
)
from app.core.exceptions import ForbiddenError, NotFoundError
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import registration as registration_service
from app.services import ticket as ticket_service

router = APIRouter()


def _parse_iso_datetime(v: str | None) -> datetime | None:
    if v is None:
        return None
    dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _event_to_response(
    e: Event,
    *,
    total_pledged_cents: int | None = None,
    funding_days_left: int | None = None,
) -> EventResponse:
    """Build response; e.venue must be loaded so everyone can see venue info when viewing an event."""
    venue_info = EventVenueInfo.model_validate(e.venue) if e.venue else None
    if venue_info is None:
        raise ValueError("Event.venue must be loaded when building EventResponse")
    return EventResponse(
        id=e.id,
        organizer_id=e.organizer_id,
        venue_id=e.venue_id,
        venue=venue_info,
        title=e.title,
        description=e.description,
        start_time=e.start_time,
        end_time=e.end_time,
        status=e.status.value,
        registration_type=e.registration_type.value,
        max_capacity=e.max_capacity,
        funding_goal_cents=e.funding_goal_cents,
        funding_end_at=e.funding_end_at,
        total_pledged_cents=total_pledged_cents,
        funding_days_left=funding_days_left,
        min_pledge_cents=e.min_pledge_cents,
        common_discount_percent=e.common_discount_percent,
        pledge_discount_percent=e.pledge_discount_percent,
        lat=e.lat,
        lng=e.lng,
        created_at=e.created_at,
        updated_at=e.updated_at,
    )


def _parse_date_or_datetime(v: str | None, end_of_day: bool = False) -> datetime | None:
    """Parse ISO date (YYYY-MM-DD) or datetime; return as UTC. If date only: start of day or end of day."""
    if v is None:
        return None
    v = v.strip()
    if not v:
        return None
    try:
        if "T" in v or " " in v or (len(v) >= 19 and v[10:11] in ("T", " ")):
            dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
        else:
            d = date.fromisoformat(v)
            if end_of_day:
                dt = datetime.combine(d, datetime.max.time()).replace(tzinfo=timezone.utc)
            else:
                dt = datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except (ValueError, TypeError):
        return None


@router.get("", response_model=list[EventResponse])
async def list_events(
    db: DbSession,
    search: str | None = Query(None, description="Search in event title and description"),
    city: str | None = Query(None, description="e.g. Ottawa"),
    status: str | None = Query(None),
    live: bool | None = Query(None),
    registration_type: str | None = Query(None),
    organizer_id: int | None = Query(None),
    date_from: str | None = Query(None, description="Events starting on or after (ISO date or datetime)"),
    date_to: str | None = Query(None, description="Events starting on or before (ISO date or datetime)"),
    has_funding: bool | None = Query(None, description="True = has goal or deadline; False = no funding"),
    has_tickets: bool | None = Query(None, description="True = has ticket tiers; False = no tiers"),
    min_capacity: int | None = Query(None, description="Event max_capacity >= this"),
    max_capacity: int | None = Query(None, description="Event max_capacity <= this"),
):
    """List events with optional search and filters."""
    date_from_dt = _parse_date_or_datetime(date_from, end_of_day=False)
    date_to_dt = _parse_date_or_datetime(date_to, end_of_day=True)
    events = await event_service.list_events(
        db,
        search=search,
        city=city,
        status=status,
        live=live,
        registration_type=registration_type,
        organizer_id=organizer_id,
        date_from=date_from_dt,
        date_to=date_to_dt,
        has_funding=has_funding,
        has_tickets=has_tickets,
        min_capacity=min_capacity,
        max_capacity=max_capacity,
    )
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids)
    now = datetime.now(timezone.utc)
    out = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0  # 0 = ended
        out.append(
            _event_to_response(
                e,
                total_pledged_cents=total_cents,
                funding_days_left=days_left,
            )
        )
    return out


@router.post("", response_model=EventResponse)
async def create_event(
    body: EventCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create event (organizer or admin). Organizer is set to current user."""
    start_time = _parse_iso_datetime(body.start_time)
    end_time = _parse_iso_datetime(body.end_time)
    funding_end_at = _parse_iso_datetime(body.funding_end_at)
    if not start_time or not end_time:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="start_time and end_time required as ISO datetime")
    reg_type = RegistrationType(body.registration_type)
    event = await event_service.create(
        db,
        organizer_id=current_user.id,
        venue_id=body.venue_id,
        title=body.title,
        description=body.description,
        start_time=start_time,
        end_time=end_time,
        funding_goal_cents=body.funding_goal_cents,
        funding_end_at=funding_end_at,
        min_pledge_cents=body.min_pledge_cents,
        registration_type=reg_type,
        max_capacity=body.max_capacity,
        common_discount_percent=body.common_discount_percent,
        pledge_discount_percent=body.pledge_discount_percent,
        allow_any_venue=(current_user.role == UserRole.admin),
    )
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(event_id: int, db: DbSession):
    """Event detail (public). Includes venue so everyone can see where the event is."""
    event = await event_service.get_by_id(db, event_id, load_venue=True)
    if not event:
        raise NotFoundError("Event", event_id)
    summary = await funding_service.get_summary(db, event_id=event_id)
    now = datetime.now(timezone.utc)
    days_left = None
    if event.funding_end_at is not None:
        end = event.funding_end_at if event.funding_end_at.tzinfo else event.funding_end_at.replace(tzinfo=timezone.utc)
        delta = (end - now).days
        days_left = max(0, delta) if delta > 0 else 0
    return _event_to_response(
        event,
        total_pledged_cents=summary["total_pledged_cents"],
        funding_days_left=days_left,
    )


def _event_to_ics(event: Event) -> str:
    """Build iCalendar (.ics) string for the event. Event.venue must be loaded for location."""
    def ical_dt(dt: datetime) -> str:
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y%m%dT%H%M%SZ")

    now = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    uid = f"event-{event.id}@crowdfund"
    summary = (event.title or "Event").replace("\r", "").replace("\n", " ")
    description = (event.description or "").replace("\r", " ").replace("\n", " ")
    location = ""
    if event.venue:
        parts = [event.venue.name, event.venue.address, event.venue.city]
        if event.venue.province:
            parts.append(event.venue.province)
        location = ", ".join(p for p in parts if p).replace("\r", " ").replace("\n", " ")
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//CrowdFund Event//EN",
        "CALSCALE:GREGORIAN",
        "BEGIN:VEVENT",
        f"UID:{uid}",
        f"DTSTAMP:{now}",
        f"DTSTART:{ical_dt(event.start_time)}",
        f"DTEND:{ical_dt(event.end_time)}",
        f"SUMMARY:{summary}",
        f"DESCRIPTION:{description}",
        f"LOCATION:{location}",
        "END:VEVENT",
        "END:VCALENDAR",
    ]
    return "\r\n".join(lines)


@router.get("/{event_id}/calendar.ics")
async def get_event_calendar(event_id: int, db: DbSession):
    """Add to calendar: returns iCalendar (.ics) file for the event. Public."""
    event = await event_service.get_by_id(db, event_id, load_venue=True)
    if not event:
        raise NotFoundError("Event", event_id)
    ics = _event_to_ics(event)
    filename = "".join(c if c.isalnum() or c in " -_" else "_" for c in (event.title or "event")[:80]) + ".ics"
    return Response(
        content=ics,
        media_type="text/calendar",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.patch("/{event_id}", response_model=EventResponse)
async def update_event(
    event_id: int,
    body: EventUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update event (main organizer, co-organizer, or admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot update this event")
    start_time = _parse_iso_datetime(body.start_time) if body.start_time else None
    end_time = _parse_iso_datetime(body.end_time) if body.end_time else None
    funding_end_at = _parse_iso_datetime(body.funding_end_at) if body.funding_end_at is not None else None
    reg_type = RegistrationType(body.registration_type) if body.registration_type is not None else None
    updated = await event_service.update(
        db,
        event,
        title=body.title,
        description=body.description,
        start_time=start_time,
        end_time=end_time,
        funding_goal_cents=body.funding_goal_cents,
        funding_end_at=funding_end_at,
        min_pledge_cents=body.min_pledge_cents,
        registration_type=reg_type,
        max_capacity=body.max_capacity,
        common_discount_percent=body.common_discount_percent,
        pledge_discount_percent=body.pledge_discount_percent,
    )
    updated = await event_service.get_by_id(db, updated.id, load_venue=True)
    return _event_to_response(updated)


@router.post("/{event_id}/cancel", response_model=EventResponse)
async def cancel_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Organizer (main or co-) cancels the event anytime (except already cancelled or ended)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot cancel this event")
    event = await event_service.cancel_event(db, event, current_user)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/extend-funding", response_model=EventResponse)
async def extend_funding(
    event_id: int,
    body: ExtendFundingBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """After funding deadline: extend funding period and/or set event date. At least one of funding_end_at, start_time, end_time required."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot update this event")
    if not any([body.funding_end_at, body.start_time, body.end_time]):
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="At least one of funding_end_at, start_time, end_time required")
    new_funding_end_at = _parse_iso_datetime(body.funding_end_at)
    new_start = _parse_iso_datetime(body.start_time)
    new_end = _parse_iso_datetime(body.end_time)
    event = await event_service.extend_funding_and_set_event_date(
        db, event, current_user,
        new_funding_end_at=new_funding_end_at,
        new_start_time=new_start,
        new_end_time=new_end,
    )
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.delete("/{event_id}")
async def delete_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete (draft/pending) or cancel event (main organizer, co-organizer, or admin)."""
    event = await event_service.get_or_404(db, event_id)
    await event_service.delete_or_cancel(db, event, current_user)
    return {"ok": True}


# ----- Event co-organizers (main organizer only can add/remove) -----
@router.get("/{event_id}/organizers", response_model=list[EventOrganizerItem])
async def list_event_organizers(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List main + co-organizers for the event. Requires main organizer, co-organizer, or admin."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view organizers for this event")
    main, co_organizers = await event_service.list_event_organizers(db, event_id=event_id)
    out = [
        EventOrganizerItem(
            user_id=main.id,
            display_name=main.display_name,
            email=main.email,
            is_main=True,
        ),
    ]
    for eo in co_organizers:
        u = eo.user
        out.append(
            EventOrganizerItem(
                user_id=u.id,
                display_name=u.display_name,
                email=u.email,
                is_main=False,
            ),
        )
    return out


@router.post("/{event_id}/organizers")
async def add_event_organizer(
    event_id: int,
    body: AddEventOrganizerBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Add a co-organizer (main organizer only). User must have organizer role."""
    event = await event_service.get_or_404(db, event_id)
    if not event_service.is_main_organizer(current_user, event):
        raise ForbiddenError("Only the main organizer can add co-organizers")
    eo = await event_service.add_event_organizer(db, event_id=event_id, user_id=body.user_id, added_by=current_user)
    return {"id": eo.id, "event_id": eo.event_id, "user_id": eo.user_id}


@router.delete("/{event_id}/organizers/{user_id}")
async def remove_event_organizer(
    event_id: int,
    user_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Remove a co-organizer (main organizer only)."""
    event = await event_service.get_or_404(db, event_id)
    if not event_service.is_main_organizer(current_user, event):
        raise ForbiddenError("Only the main organizer can remove co-organizers")
    await event_service.remove_event_organizer(db, event_id=event_id, user_id=user_id, removed_by=current_user)
    return {"ok": True}


@router.post("/{event_id}/submit", response_model=EventResponse)
async def submit_event_for_approval(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Submit draft event for admin approval (draft → pending_approval). Organizer or admin only."""
    event = await event_service.submit_for_approval(db, event_id=event_id, user=current_user)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/pledge")
async def pledge_event(
    event_id: int,
    body: PledgeBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Pledge to event (customer)."""
    pledge = await funding_service.create_pledge(
        db,
        event_id=event_id,
        user=current_user,
        amount_cents=body.amount_cents,
    )
    return PledgeResponse(
        id=pledge.id,
        event_id=pledge.event_id,
        user_id=pledge.user_id,
        amount_cents=pledge.amount_cents,
        status=pledge.status.value,
        created_at=pledge.created_at,
    )


@router.get("/{event_id}/funding")
async def get_event_funding(event_id: int, db: DbSession):
    """Funding summary for event (public or organizer/admin)."""
    summary = await funding_service.get_summary(db, event_id=event_id)
    return FundingSummaryResponse(**summary)


@router.post("/{event_id}/register")
async def register_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Register for event (open: first-come; closed: request). Check capacity."""
    reg = await registration_service.register(db, event_id=event_id, user=current_user)
    return RegistrationResponse(
        id=reg.id,
        event_id=reg.event_id,
        user_id=reg.user_id,
        status=reg.status.value,
        created_at=reg.created_at,
    )


@router.post("/{event_id}/unregister", response_model=UnregisterResponse)
async def unregister_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Customer unregisters from event. Pledges refunded only if more than 7 days before funding deadline."""
    result = await registration_service.unregister(db, event_id=event_id, user=current_user)
    return UnregisterResponse(
        refunded_cents=result["refunded_cents"],
        pledges_refunded=result["pledges_refunded"],
    )


@router.get("/{event_id}/registrations")
async def list_registrations(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List registrations for event (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view registrations for this event")
    regs = await registration_service.list_registrations(db, event_id=event_id)
    return [
        RegistrationResponse(
            id=r.id,
            event_id=r.event_id,
            user_id=r.user_id,
            status=r.status.value,
            created_at=r.created_at,
        )
        for r in regs
    ]


@router.post("/{event_id}/registrations/{registration_id}/decision", response_model=RegistrationResponse)
async def decide_registration(
    event_id: int,
    registration_id: int,
    body: RegistrationDecisionBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """
    Organizer/admin approves or rejects a waitlist request.
    - approve: waitlist -> registered (if capacity allows)
    - reject: waitlist -> cancelled
    """
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot manage registrations for this event")

    if body.action == "approve":
        reg = await registration_service.approve_waitlist(
            db, event_id=event_id, registration_id=registration_id
        )
    else:
        reg = await registration_service.reject_waitlist(
            db, event_id=event_id, registration_id=registration_id
        )

    return RegistrationResponse(
        id=reg.id,
        event_id=reg.event_id,
        user_id=reg.user_id,
        status=reg.status.value,
        created_at=reg.created_at,
    )


# ----- Ticket tiers (organizer) -----
@router.get("/{event_id}/tiers", response_model=list[TicketTierResponse])
async def list_tiers(event_id: int, db: DbSession):
    """List ticket tiers for an event (public)."""
    tiers = await ticket_service.list_tiers(db, event_id=event_id)
    return [TicketTierResponse.model_validate(t) for t in tiers]


@router.post("/{event_id}/tiers", response_model=TicketTierResponse)
async def create_tier(
    event_id: int,
    body: TicketTierCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create a ticket tier (organizer/admin)."""
    tier = await ticket_service.create_tier(
        db, event_id=event_id, user=current_user,
        name=body.name, price_cents=body.price_cents, display_order=body.display_order,
    )
    return TicketTierResponse.model_validate(tier)


@router.patch("/{event_id}/tiers/{tier_id}", response_model=TicketTierResponse)
async def update_tier(
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
        name=body.name, price_cents=body.price_cents, display_order=body.display_order,
    )
    return TicketTierResponse.model_validate(tier)


@router.delete("/{event_id}/tiers/{tier_id}")
async def delete_tier(
    event_id: int,
    tier_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete a ticket tier (organizer/admin)."""
    tier = await ticket_service.get_tier_or_404(db, event_id=event_id, tier_id=tier_id)
    await ticket_service.delete_tier(db, tier, current_user)
    return {"ok": True}


# ----- Ticket price & purchase (customer) -----
@router.get("/{event_id}/ticket-price", response_model=TicketPricePreviewResponse)
async def get_ticket_price(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
    tier_id: int = Query(..., description="Ticket tier id"),
):
    """Preview ticket price for current user (with discounts). Customer only."""
    info = await ticket_service.compute_ticket_price(
        db, event_id=event_id, user_id=current_user.id, tier_id=tier_id
    )
    return TicketPricePreviewResponse(**info)


@router.post("/{event_id}/purchase-ticket", response_model=TicketSaleResponse)
async def purchase_ticket(
    event_id: int,
    body: TicketPurchaseBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Purchase a ticket (customer, must be registered). Returns ticket with ticket_code for QR."""
    sale = await ticket_service.purchase_ticket(
        db, event_id=event_id, user=current_user,
        tier_id=body.tier_id, extra_perks=body.extra_perks,
    )
    return _ticket_sale_to_response(sale)


# ----- Scan ticket (organizer) -----
@router.post("/{event_id}/scan-ticket", response_model=ScanTicketResponse)
async def scan_ticket(
    event_id: int,
    body: ScanTicketBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Scan a ticket by QR code (organizer/admin). Returns ticket and already_scanned if already scanned."""
    sale, already_scanned = await ticket_service.scan_ticket(
        db, event_id=event_id, ticket_code=body.ticket_code, scanned_by_user=current_user,
    )
    return ScanTicketResponse(already_scanned=already_scanned, ticket=_ticket_sale_to_response(sale))


def _ticket_sale_to_response(sale) -> TicketSaleResponse:
    """Build TicketSaleResponse from a TicketSale (with event, ticket_tier, user, scanned_by loaded as needed)."""
    scanned_by_name = None
    if getattr(sale, "scanned_by", None) and sale.scanned_by:
        scanned_by_name = sale.scanned_by.display_name or sale.scanned_by.email
    attendee_name = None
    if getattr(sale, "user", None) and sale.user:
        attendee_name = sale.user.display_name or sale.user.email
    return TicketSaleResponse(
        id=sale.id,
        event_id=sale.event_id,
        user_id=sale.user_id,
        ticket_tier_id=sale.ticket_tier_id,
        ticket_code=sale.ticket_code,
        tier_name=sale.ticket_tier.name if sale.ticket_tier else None,
        event_title=sale.event.title if sale.event else None,
        attendee_display_name=attendee_name,
        amount_paid_cents=sale.amount_paid_cents,
        discount_applied_cents=sale.discount_applied_cents,
        extra_perks=sale.extra_perks,
        status=sale.status.value,
        scanned_at=sale.scanned_at,
        scanned_by_id=sale.scanned_by_id,
        scanned_by_display_name=scanned_by_name,
        created_at=sale.created_at,
    )


# ----- Ticket sales list & user discounts (organizer) -----
@router.get("/{event_id}/ticket-sales", response_model=list[TicketSaleResponse])
async def list_event_ticket_sales(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List ticket sales for event (organizer/admin). Includes scanned_at and scanned_by for scan list view."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view ticket sales for this event")
    sales = await ticket_service.list_event_ticket_sales(db, event_id=event_id)
    return [_ticket_sale_to_response(s) for s in sales]


@router.post("/{event_id}/discounts")
async def set_user_discount(
    event_id: int,
    body: UserDiscountBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Set selective discount for a user on this event (organizer/admin)."""
    ued = await ticket_service.set_user_discount(
        db, event_id=event_id, target_user_id=body.user_id, current_user=current_user,
        discount_type=body.discount_type, value=body.value,
    )
    return {"id": ued.id, "event_id": ued.event_id, "user_id": ued.user_id, "discount_type": ued.discount_type, "value": ued.value}


@router.delete("/{event_id}/discounts/{user_id}")
async def remove_user_discount(
    event_id: int,
    user_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Remove selective discount for a user (organizer/admin)."""
    await ticket_service.remove_user_discount(
        db, event_id=event_id, target_user_id=user_id, current_user=current_user,
    )
    return {"ok": True}
