"""
Users: profile (GET/PATCH /me), my pledges (GET /me/pledges), my tickets (GET /me/tickets), my events (GET /me/events), KYC.
"""
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile

from app.dependencies import CurrentUser, DbSession, ReadDbSession, require_role
from app.logger import get_logger, log_step

logger = get_logger("api.users")
from app.rate_limit import limiter, dynamic_limit
from app.models.user import User, UserRole
from app.models.kyc_document import KycDocumentType
from app.schemas import (
    EventResponse, MeResponse, MeUpdate, MyPledgeItem, OrganizerPledgeItem,
    OrganizerDashboardResponse, OrganizerTimeSeriesResponse,
    PledgeReceiptResponse, TicketReceiptResponse, TicketSaleResponse,
)
from app.schemas.kyc import KycDocumentResponse, KycStatusResponse, KycSubmitResponse
from fastapi import Query

from app.api.v1.events import _event_to_response, _get_first_images, _ticket_sale_to_response
from app.repositories.user_repo import user_repo
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import ticket as ticket_service
from app.services import kyc_verification as kyc_svc
from app.services import platform_settings as settings_svc
from app.services import user_service
from app.services.upload_validation import validate_upload

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
        kyc_status=u.kyc_status,
        kyc_verified=u.kyc_verified,
        kyc_verified_at=u.kyc_verified_at,
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
    log_step(logger, "Updating profile", user_id=current_user.id)
    # Re-fetch user in the write session (current_user comes from read session)
    user = await user_repo.get_by_id(db, current_user.id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    kwargs: dict = {}
    for field in ("display_name", "phone", "address", "birthday", "years_of_experience",
                  "bio", "website_url", "contact_email",
                  "instagram", "twitter", "facebook", "linkedin", "youtube", "tiktok"):
        val = getattr(body, field, None)
        if val is not None:
            kwargs[field] = val
    if kwargs:
        user = await user_repo.update_user(db, user, **kwargs)
    return _me_response(user)


@router.get("/search-organizers")
async def search_organizers(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    q: str = Query("", min_length=1, description="Search by email or display name"),
    limit: int = Query(10, ge=1, le=20),
):
    """Search users with organizer role by email or display name. For co-organizer invite."""
    results = await user_repo.search_organizers(db, q, limit=limit)
    return [
        {"id": u.id, "email": u.email, "display_name": u.display_name}
        for u in results
        if u.id != current_user.id
    ]


@router.get("/pledges", response_model=list[MyPledgeItem])
async def get_my_pledges(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    sort_by: str = Query("newest", description="Sort: newest, oldest, amount_high, amount_low"),
):
    """List events the current user has pledged to."""
    from app.api.v1.events import _build_tier_reservation_response
    pledges = await funding_service.list_pledges_by_user(db, user_id=current_user.id, offset=offset, limit=limit, sort_by=sort_by)
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
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
):
    """Get a pledge receipt for the current user."""
    data = await user_service.get_pledge_receipt(
        db, pledge_id=pledge_id, user_id=current_user.id,
        user_display_name=current_user.display_name,
    )
    pledge = data["pledge"]
    return PledgeReceiptResponse(
        id=pledge.id,
        receipt_number=pledge.receipt_number,
        event_id=pledge.event_id,
        event_title=data["event"].title,
        user_id=pledge.user_id,
        backer_name=data["backer_name"],
        amount_cents=pledge.amount_cents,
        reserved_spots=pledge.reserved_spots,
        tier_reservations=data["tier_reservations"],
        platform_cut_cents=pledge.platform_cut_cents,
        net_to_organizer_cents=pledge.net_to_organizer_cents,
        funding_commission_percent=data["funding_commission_percent"],
        status=pledge.status.value,
        is_guest=pledge.is_guest,
        created_at=pledge.created_at,
    )


@router.get("/organizer-pledges", response_model=list[OrganizerPledgeItem])
async def get_organizer_pledges(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    status: str | None = Query(None, description="Filter by pledge status (pledged, refunded, etc.)"),
    event_status: str | None = Query(None, description="Filter to events with this status"),
    genre: str | None = Query(None, description="Filter to events with this genre"),
    event_id: int | None = Query(None, description="Filter to a single event"),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List all pledges made to events organized by the current user."""
    pledges = await funding_service.list_organizer_pledges(
        db, organizer_id=current_user.id, status_filter=status,
        event_status=event_status, genre=genre, event_id=event_id,
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
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    sort_by: str = Query("newest", description="Sort: newest, oldest, price_high, price_low"),
):
    """List tickets the current user has purchased (customer only). Includes ticket_code for QR and scanned_at (already scanned)."""
    sales = await ticket_service.list_my_tickets(db, user_id=current_user.id, offset=offset, limit=limit, sort_by=sort_by)
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
            event_status=s.event.status.value if s.event else None,
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
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Get receipt for a specific ticket the current user purchased."""
    sale = await ticket_service.get_ticket_receipt(db, sale_id=sale_id, user_id=current_user.id)
    info = await user_service.get_ticket_receipt(db, sale)

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
        organizer_name=info["organizer_name"],
        organizer_email=info["organizer_email"],
        organizer_phone=info["organizer_phone"],
        venue_name=info["venue_name"],
        venue_address=info["venue_address"],
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
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    scanned_only: bool = Query(False, description="If true, return only scanned tickets"),
    event_status: str | None = Query(None, description="Filter to events with this status"),
    genre: str | None = Query(None, description="Filter to events with this genre"),
    event_id: int | None = Query(None, description="Filter to a single event"),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """All ticket sales across every event the current user organizes. Single query."""
    sales = await ticket_service.list_organizer_ticket_sales(
        db, organizer_id=current_user.id, scanned_only=scanned_only,
        event_status=event_status, genre=genre, event_id=event_id,
        offset=offset, limit=limit,
    )
    return [_ticket_sale_to_response(s) for s in sales]


@router.get("/organizer-refund-requests", response_model=list[TicketSaleResponse])
async def get_my_organizer_refund_requests(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    event_id: int | None = Query(None, description="Filter to a single event"),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """All pending refund requests across every event the current user organizes."""
    sales = await ticket_service.list_organizer_refund_requests(
        db, organizer_id=current_user.id,
        event_id=event_id, offset=offset, limit=limit,
    )
    return [_ticket_sale_to_response(s) for s in sales]


@router.get("/events", response_model=list[EventResponse])
async def get_my_events(
    db: ReadDbSession,
    current_user: CurrentUser,
    offset: int = Query(0, ge=0, description="Pagination offset"),
    limit: int = Query(20, ge=1, le=100, description="Page size (max 100)"),
    sort_by: str = Query("newest", description="Sort: newest, oldest, name_az, soonest"),
):
    """Events the current user is registered to (includes cancelled events so the user can see cancellation reasons)."""
    from datetime import datetime, timezone
    events = await event_service.get_my_registered_events(db, user_id=current_user.id, offset=offset, limit=limit, sort_by=sort_by)
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    first_images = await _get_first_images(db, event_ids) if event_ids else {}
    now = datetime.now(timezone.utc)
    out = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        out.append(_event_to_response(e, total_pledged_cents=total_cents, funding_days_left=days_left, first_image_url=first_images.get(e.id)))
    return out


@router.get("/co-organized-events", response_model=list[EventResponse])
async def get_co_organized_events(
    db: ReadDbSession,
    current_user: CurrentUser,
    status: str | None = Query(None, description="Filter by event status"),
    search: str | None = Query(None, description="Search by event title"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    limit: int = Query(20, ge=1, le=100, description="Page size (max 100)"),
):
    """Events the current user is an accepted co-organizer of."""
    from datetime import datetime, timezone
    events = await event_service.get_co_organized_events(
        db, user_id=current_user.id, status=status, search=search,
        offset=offset, limit=limit,
    )
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    first_images = await _get_first_images(db, event_ids) if event_ids else {}
    now = datetime.now(timezone.utc)
    out = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        out.append(_event_to_response(e, total_pledged_cents=total_cents, funding_days_left=days_left, first_image_url=first_images.get(e.id)))
    return out


@router.get("/customers")
async def list_my_customers(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List all customers who attended events organized by the current user, with event counts."""
    return await event_service.list_organizer_customers(db, organizer_id=current_user.id, offset=offset, limit=limit)


# ── Bookmarks ──

@router.post("/bookmarks/{event_id}")
@limiter.limit(dynamic_limit("social_action", "30/minute"))
async def toggle_bookmark(
    request: Request,
    event_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Toggle bookmark on an event. Returns current bookmarked state."""
    bookmarked = await user_service.toggle_bookmark(db, current_user.id, event_id)
    return {"bookmarked": bookmarked}


@router.get("/bookmarks/check")
async def check_bookmarks(
    db: ReadDbSession,
    current_user: CurrentUser,
    event_ids: str = Query("", description="Comma-separated event IDs"),
):
    """Batch check which events are bookmarked by the current user."""
    from app.repositories.event_repo import event_repo

    if not event_ids.strip():
        return {"bookmarked_ids": []}

    ids = [int(x.strip()) for x in event_ids.split(",") if x.strip().isdigit()]
    if not ids:
        return {"bookmarked_ids": []}

    bookmarked = await event_repo.check_bookmarks(db, current_user.id, ids)
    return {"bookmarked_ids": bookmarked}


@router.get("/bookmarks", response_model=list[EventResponse])
async def list_bookmarked_events(
    db: ReadDbSession,
    current_user: CurrentUser,
    search: str | None = Query(None, description="Search title/venue"),
    status: str | None = Query(None, description="Filter by event status"),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List events bookmarked by the current user, with optional search/status filters."""
    from datetime import datetime, timezone
    from app.repositories.event_repo import event_repo

    events = await event_repo.list_bookmarked_events(
        db, current_user.id, search=search, status=status, offset=offset, limit=limit,
    )

    now = datetime.now(timezone.utc)
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    first_images = await _get_first_images(db, event_ids) if event_ids else {}
    viewer_pledges = await funding_service.get_user_pledge_amounts_for_events(
        db, user_id=current_user.id, event_ids=event_ids
    ) if event_ids else {}
    viewer_tickets = await ticket_service.get_user_ticket_counts_for_events(
        db, user_id=current_user.id, event_ids=event_ids
    ) if event_ids else {}
    from app.repositories.sponsor_repo import sponsor_repo
    viewer_sponsor_ids = await sponsor_repo.get_viewer_sponsor_event_ids(
        db, event_ids=event_ids, user_id=current_user.id
    ) if event_ids else set()
    out = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        out.append(_event_to_response(
            e,
            total_pledged_cents=total_cents,
            funding_days_left=days_left,
            first_image_url=first_images.get(e.id),
            viewer_pledge_amount_cents=viewer_pledges.get(e.id),
            viewer_ticket_count=viewer_tickets.get(e.id),
            viewer_is_sponsor=e.id in viewer_sponsor_ids,
        ))
    return out


# ── Organizer Dashboard ────────────────────────────────────────────────


@router.get("/organizer-dashboard", response_model=OrganizerDashboardResponse)
async def get_organizer_dashboard(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    status: str | None = Query(None, description="Filter KPIs to events with this status"),
    event_id: int | None = Query(None, description="Filter KPIs to a single event"),
    genre: str | None = Query(None, description="Filter KPIs to events with this genre"),
    period: str = Query("30d", description="KPI comparison period: 7d, 30d, 90d, 1y"),
):
    """Aggregated dashboard: KPIs with deltas, status breakdown, top events, activity feed."""
    from datetime import datetime, timezone
    from app.cache import cache_json_get, cache_json_set, safe_cache_key
    from app.services.platform_settings import get_int as get_setting_int
    from app.services import dashboard as dashboard_service

    period_map = {"7d": 7, "30d": 30, "90d": 90, "1y": 365}
    delta_days = period_map.get(period, 30)

    cache_key = safe_cache_key("dashboard", current_user.id, status or "", event_id or "", genre or "", period)
    cached = await cache_json_get(cache_key)
    if cached is not None:
        return cached

    raw = await dashboard_service.get_organizer_dashboard(
        db, current_user.id, delta_days=delta_days, status_filter=status, event_id=event_id, genre=genre,
    )

    all_event_objs = list({
        e.id: e
        for e in raw["top_events"] + raw["trending_events"] + raw["popular_events"]
    }.values())
    event_ids = [e.id for e in all_event_objs]
    pledged_map = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    from app.services import ticket as ts
    tickets_sold_map = await ts.get_ticket_sold_counts_for_events(db, event_ids=event_ids) if event_ids else {}
    tier_caps_map = await ts.get_total_tier_capacity_for_events(db, event_ids=event_ids) if event_ids else {}
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
                total_tier_capacity=tier_caps_map.get(e.id, 0),
                first_image_url=first_images.get(e.id),
            ))
        return result

    resp = OrganizerDashboardResponse(
        total_revenue=raw["total_revenue"],
        tickets_sold=raw["tickets_sold"],
        total_backers=raw["total_backers"],
        total_events=raw["total_events"],
        total_sponsors=raw["total_sponsors"],
        refund_rate=raw["refund_rate"],
        status_breakdown=raw["status_breakdown"],
        top_events=_build_responses(raw["top_events"]),
        trending_events=_build_responses(raw["trending_events"]),
        popular_events=_build_responses(raw["popular_events"]),
        recent_activity=raw["recent_activity"],
    )
    ttl = await get_setting_int(db, "cache_ttl_dashboard")
    await cache_json_set(cache_key, resp.model_dump(mode="json"), ttl=ttl)
    return resp


@router.get("/organizer-dashboard/time-series", response_model=OrganizerTimeSeriesResponse)
async def get_organizer_time_series(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    days: int = Query(30, ge=7, le=365, description="Number of days (7, 30, 90, or 365)"),
    status: str | None = Query(None, description="Filter to events with this status"),
    event_id: int | None = Query(None, description="Filter to a single event"),
    genre: str | None = Query(None, description="Filter to events with this genre"),
):
    """Time-series revenue and ticket data for the organizer's events."""
    from app.services import dashboard as dashboard_service
    return await dashboard_service.get_organizer_time_series(
        db, current_user.id, days=days, status_filter=status, event_id=event_id, genre=genre,
    )


# ── KYC (Know Your Customer) ──


def _kyc_doc_response(doc) -> KycDocumentResponse:
    return KycDocumentResponse(
        id=doc.id,
        document_type=doc.document_type.value,
        file_url=f"/static/uploads/kyc/{Path(doc.file_path).name}",
        mime_type=doc.mime_type,
        original_filename=doc.original_filename,
        status=doc.status.value,
        rejection_reason=doc.rejection_reason,
        submitted_at=doc.submitted_at,
    )


@router.get("/kyc-status", response_model=KycStatusResponse)
async def get_kyc_status(db: ReadDbSession, current_user: CurrentUser):
    """Get current user's KYC verification status and documents."""
    docs = await kyc_svc.list_documents(db, current_user.id)
    role_key = f"kyc_required_{current_user.role.value}"
    required = await settings_svc.get_bool(db, role_key)
    return KycStatusResponse(
        kyc_status=current_user.kyc_status,
        kyc_verified=current_user.kyc_verified,
        kyc_verified_at=current_user.kyc_verified_at,
        kyc_required_for_role=required,
        documents=[_kyc_doc_response(d) for d in docs],
    )


@router.post("/kyc-documents", response_model=KycDocumentResponse)
@limiter.limit(dynamic_limit("file_upload", "10/minute"))
async def upload_kyc_document(
    request: Request,
    db: DbSession,
    current_user: CurrentUser,
    file: UploadFile = File(...),
    document_type: str = Form(...),
):
    """Upload a KYC document (ID front, ID back, proof of address, selfie, tax ID)."""
    try:
        doc_type = KycDocumentType(document_type)
    except ValueError:
        valid = ", ".join(t.value for t in KycDocumentType)
        raise HTTPException(400, f"Invalid document_type. Valid: {valid}")

    if current_user.kyc_status == "verified":
        raise HTTPException(400, "Already verified")
    if current_user.kyc_status == "submitted":
        raise HTTPException(400, "KYC already submitted and under review")

    file_bytes = await validate_upload(db, file, "document")

    upload_dir = Path("static/uploads/kyc")
    upload_dir.mkdir(parents=True, exist_ok=True)
    ext = Path(file.filename or "file").suffix
    filename = f"{current_user.id}_{doc_type.value}_{uuid.uuid4().hex[:8]}{ext}"
    dest = upload_dir / filename
    dest.write_bytes(file_bytes)

    doc = await kyc_svc.upload_document(
        db,
        user_id=current_user.id,
        document_type=doc_type,
        file_path=str(dest),
        mime_type=file.content_type or "application/octet-stream",
        original_filename=file.filename or "unknown",
    )
    await db.commit()
    return _kyc_doc_response(doc)


@router.delete("/kyc-documents/{document_id}")
async def delete_kyc_document(
    document_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Delete a pending KYC document."""
    try:
        await kyc_svc.delete_document(db, current_user.id, document_id)
        await db.commit()
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"ok": True}


@router.post("/kyc-submit", response_model=KycSubmitResponse)
async def submit_kyc(db: DbSession, current_user: CurrentUser):
    """Submit uploaded documents for KYC verification."""
    try:
        result = await kyc_svc.submit_for_review(db, current_user.id)
        await db.commit()
    except ValueError as e:
        raise HTTPException(400, str(e))

    status_msg = {
        "verified": "Identity verified successfully.",
        "rejected": f"Verification rejected: {result.reason}",
        "pending": "Documents submitted for admin review.",
    }
    return KycSubmitResponse(
        kyc_status=result.status if result.status != "pending" else "submitted",
        message=status_msg.get(result.status, "Submitted"),
    )
