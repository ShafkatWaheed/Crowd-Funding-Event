"""
Users: profile (GET/PATCH /me), my pledges (GET /me/pledges), my tickets (GET /me/tickets), my events (GET /me/events).
"""
from fastapi import APIRouter, Depends

from app.dependencies import CurrentUser, DbSession, require_role
from app.models.user import User, UserRole
from app.schemas import (
    EventResponse, MeResponse, MeUpdate, MyPledgeItem, OrganizerPledgeItem,
    OrganizerDashboardResponse, OrganizerTimeSeriesResponse,
    PledgeReceiptResponse, TicketReceiptResponse, TicketSaleResponse,
)
from fastapi import Query

from app.api.v1.events import _event_to_response, _get_first_images, _ticket_sale_to_response
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import ticket as ticket_service

router = APIRouter()


def _me_response(u) -> MeResponse:
    return MeResponse(
        id=u.id,
        email=u.email,
        display_name=u.display_name,
        phone=u.phone,
        role=u.role.value,
        address=u.address,
        birthday=u.birthday,
        years_of_experience=u.years_of_experience,
    )


@router.get("", response_model=MeResponse)
async def get_me(current_user: CurrentUser):
    """Current user profile."""
    return _me_response(current_user)


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
    if body.address is not None:
        current_user.address = body.address
    if body.birthday is not None:
        current_user.birthday = body.birthday
    if body.years_of_experience is not None:
        current_user.years_of_experience = body.years_of_experience
    await db.flush()
    await db.refresh(current_user)
    return _me_response(current_user)


@router.get("/pledges", response_model=list[MyPledgeItem])
async def get_my_pledges(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List events the current user has pledged to."""
    from app.api.v1.events import _build_tier_reservation_response
    pledges = await funding_service.list_pledges_by_user(db, user_id=current_user.id, offset=offset, limit=limit)
    result = []
    for p in pledges:
        tier_resp = await _build_tier_reservation_response(db, p.id)
        result.append(MyPledgeItem(
            id=p.id,
            event_id=p.event_id,
            event_title=p.event.title if p.event else "",
            amount_cents=p.amount_cents,
            reserved_spots=p.reserved_spots,
            tier_reservations=tier_resp,
            receipt_number=p.receipt_number,
            status=p.status.value,
            is_guest=p.is_guest,
            created_at=p.created_at,
        ))
    return result


@router.get("/pledges/{pledge_id}/receipt", response_model=PledgeReceiptResponse)
async def get_my_pledge_receipt(
    pledge_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
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
    from app.api.v1.events import _build_tier_reservation_response
    tier_resp = await _build_tier_reservation_response(db, pledge.id)
    return PledgeReceiptResponse(
        id=pledge.id,
        receipt_number=pledge.receipt_number,
        event_id=pledge.event_id,
        event_title=event.title,
        user_id=pledge.user_id,
        backer_name=current_user.display_name,
        amount_cents=pledge.amount_cents,
        reserved_spots=pledge.reserved_spots,
        tier_reservations=tier_resp,
        platform_cut_cents=pledge.platform_cut_cents,
        net_to_organizer_cents=pledge.net_to_organizer_cents,
        funding_commission_percent=funding_pct,
        status=pledge.status.value,
        is_guest=pledge.is_guest,
        created_at=pledge.created_at,
    )


@router.get("/organizer-pledges", response_model=list[OrganizerPledgeItem])
async def get_organizer_pledges(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    status: str | None = Query(None, description="Filter by pledge status (pledged, refunded, etc.)"),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List all pledges made to events organized by the current user."""
    pledges = await funding_service.list_organizer_pledges(
        db, organizer_id=current_user.id, status_filter=status,
        offset=offset, limit=limit,
    )
    return [
        OrganizerPledgeItem(
            id=p.id,
            event_id=p.event_id,
            event_title=p.event.title if p.event else "",
            backer_name=p.user.display_name if p.user and p.user.display_name else f"User #{p.user_id}",
            amount_cents=p.amount_cents,
            net_to_organizer_cents=p.net_to_organizer_cents,
            reserved_spots=p.reserved_spots,
            receipt_number=p.receipt_number,
            status=p.status.value,
            is_guest=p.is_guest,
            created_at=p.created_at,
        )
        for p in pledges
    ]


@router.get("/tickets", response_model=list[TicketSaleResponse])
async def get_my_tickets(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List tickets the current user has purchased (customer only). Includes ticket_code for QR and scanned_at (already scanned)."""
    sales = await ticket_service.list_my_tickets(db, user_id=current_user.id, offset=offset, limit=limit)
    return [
        TicketSaleResponse(
            id=s.id,
            event_id=s.event_id,
            user_id=s.user_id,
            ticket_tier_id=s.ticket_tier_id,
            purchase_group_id=getattr(s, "purchase_group_id", None),
            ticket_code=s.ticket_code,
            receipt_number=getattr(s, "receipt_number", None),
            tier_name=s.ticket_tier.name if s.ticket_tier else None,
            event_title=s.event.title if s.event else None,
            attendee_display_name=s.user.display_name if s.user else None,
            amount_paid_cents=s.amount_paid_cents,
            discount_applied_cents=s.discount_applied_cents,
            commission_cents=getattr(s, "commission_cents", 0) or 0,
            net_to_organizer_cents=getattr(s, "net_to_organizer_cents", 0) or 0,
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
        extra_perks=sale.extra_perks,
        purchased_at=sale.created_at,
        scanned_at=sale.scanned_at,
    )


@router.get("/organizer-ticket-sales", response_model=list[TicketSaleResponse])
async def get_my_organizer_ticket_sales(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    scanned_only: bool = Query(False, description="If true, return only scanned tickets"),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """All ticket sales across every event the current user organizes. Single query."""
    sales = await ticket_service.list_organizer_ticket_sales(
        db, organizer_id=current_user.id, scanned_only=scanned_only,
        offset=offset, limit=limit,
    )
    return [_ticket_sale_to_response(s) for s in sales]


@router.get("/events", response_model=list[EventResponse])
async def get_my_events(
    db: DbSession,
    current_user: CurrentUser,
    offset: int = Query(0, ge=0, description="Pagination offset"),
    limit: int = Query(20, ge=1, le=100, description="Page size (max 100)"),
):
    """Events the current user is registered to (includes cancelled events so the user can see cancellation reasons)."""
    from datetime import datetime, timezone
    events = await event_service.get_my_registered_events(db, user_id=current_user.id, offset=offset, limit=limit)
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    now = datetime.now(timezone.utc)
    out = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        out.append(_event_to_response(e, total_pledged_cents=total_cents, funding_days_left=days_left))
    return out


@router.get("/customers")
async def list_my_customers(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List all customers who attended events organized by the current user, with event counts."""
    return await event_service.list_organizer_customers(db, organizer_id=current_user.id, offset=offset, limit=limit)


# ── Bookmarks ──

@router.post("/bookmarks/{event_id}")
async def toggle_bookmark(
    event_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Toggle bookmark on an event. Returns current bookmarked state."""
    from sqlalchemy import select, delete
    from app.models.bookmark import Bookmark

    existing = (await db.execute(
        select(Bookmark).where(Bookmark.user_id == current_user.id, Bookmark.event_id == event_id)
    )).scalar_one_or_none()

    if existing:
        await db.execute(
            delete(Bookmark).where(Bookmark.id == existing.id)
        )
        await db.flush()
        return {"bookmarked": False}

    await event_service.get_or_404(db, event_id)
    db.add(Bookmark(user_id=current_user.id, event_id=event_id))
    await db.flush()
    return {"bookmarked": True}


@router.get("/bookmarks/check")
async def check_bookmarks(
    db: DbSession,
    current_user: CurrentUser,
    event_ids: str = Query("", description="Comma-separated event IDs"),
):
    """Batch check which events are bookmarked by the current user."""
    from sqlalchemy import select
    from app.models.bookmark import Bookmark

    if not event_ids.strip():
        return {"bookmarked_ids": []}

    ids = [int(x.strip()) for x in event_ids.split(",") if x.strip().isdigit()]
    if not ids:
        return {"bookmarked_ids": []}

    result = await db.execute(
        select(Bookmark.event_id).where(
            Bookmark.user_id == current_user.id,
            Bookmark.event_id.in_(ids),
        )
    )
    return {"bookmarked_ids": list(result.scalars().all())}


@router.get("/bookmarks", response_model=list[EventResponse])
async def list_bookmarked_events(
    db: DbSession,
    current_user: CurrentUser,
    search: str | None = Query(None, description="Search title/venue"),
    status: str | None = Query(None, description="Filter by event status"),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List events bookmarked by the current user, with optional search/status filters."""
    from datetime import datetime, timezone
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload
    from app.models.bookmark import Bookmark
    from app.models.event import Event as EventModel

    q = (
        select(EventModel)
        .join(Bookmark, Bookmark.event_id == EventModel.id)
        .where(Bookmark.user_id == current_user.id)
        .options(selectinload(EventModel.venue), selectinload(EventModel.organizer), selectinload(EventModel.ticket_strategy))
        .order_by(Bookmark.created_at.desc())
    )

    if search and search.strip():
        term = f"%{search.strip()}%"
        from sqlalchemy import or_
        from app.models.venue import Venue
        q = q.outerjoin(Venue, EventModel.venue_id == Venue.id)
        q = q.where(or_(
            EventModel.title.ilike(term),
            Venue.name.ilike(term),
            Venue.city.ilike(term),
        ))
    if status:
        q = q.where(EventModel.status == status)

    q = q.offset(offset).limit(limit)
    events = (await db.execute(q)).scalars().unique().all()

    now = datetime.now(timezone.utc)
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    out = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        out.append(_event_to_response(e, total_pledged_cents=total_cents, funding_days_left=days_left))
    return out


# ── Organizer Dashboard ────────────────────────────────────────────────


@router.get("/organizer-dashboard", response_model=OrganizerDashboardResponse)
async def get_organizer_dashboard(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    status: str | None = Query(None, description="Filter KPIs to events with this status"),
    event_id: int | None = Query(None, description="Filter KPIs to a single event"),
):
    """Aggregated dashboard: KPIs with deltas, status breakdown, top events, activity feed."""
    from datetime import datetime, timezone
    from app.services import dashboard as dashboard_service

    raw = await dashboard_service.get_organizer_dashboard(
        db, current_user.id, status_filter=status, event_id=event_id,
    )

    all_event_objs = list({
        e.id: e
        for e in raw["top_events"] + raw["trending_events"] + raw["popular_events"]
    }.values())
    event_ids = [e.id for e in all_event_objs]
    pledged_map = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    from app.services import ticket as ts
    tickets_sold_map = await ts.get_ticket_sold_counts_for_events(db, event_ids=event_ids) if event_ids else {}
    first_images = await _get_first_images(db, event_ids) if event_ids else {}

    now = datetime.now(timezone.utc)

    def _build_responses(events: list) -> list:
        result = []
        for e in events:
            total_cents = pledged_map.get(e.id, 0)
            days_left = None
            if e.funding_end_at is not None:
                end_dt = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
                d = (end_dt - now).days
                days_left = max(0, d) if d > 0 else 0
            result.append(_event_to_response(
                e,
                total_pledged_cents=total_cents,
                funding_days_left=days_left,
                tickets_sold_count=tickets_sold_map.get(e.id, 0),
                first_image_url=first_images.get(e.id),
            ))
        return result

    return OrganizerDashboardResponse(
        total_revenue=raw["total_revenue"],
        tickets_sold=raw["tickets_sold"],
        total_backers=raw["total_backers"],
        total_events=raw["total_events"],
        total_sponsors=raw["total_sponsors"],
        status_breakdown=raw["status_breakdown"],
        top_events=_build_responses(raw["top_events"]),
        trending_events=_build_responses(raw["trending_events"]),
        popular_events=_build_responses(raw["popular_events"]),
        recent_activity=raw["recent_activity"],
    )


@router.get("/organizer-dashboard/time-series", response_model=OrganizerTimeSeriesResponse)
async def get_organizer_time_series(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    days: int = Query(30, ge=7, le=90, description="Number of days (7, 30, or 90)"),
    status: str | None = Query(None, description="Filter to events with this status"),
    event_id: int | None = Query(None, description="Filter to a single event"),
):
    """Time-series revenue and ticket data for the organizer's events."""
    from app.services import dashboard as dashboard_service
    return await dashboard_service.get_organizer_time_series(
        db, current_user.id, days=days, status_filter=status, event_id=event_id,
    )
