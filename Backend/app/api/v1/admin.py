"""
Admin: approve/reject events, list pending, stats, platform settings.
"""
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel as _BaseModel

from app.services import audit as audit_svc

from app.dependencies import DbSession, ReadDbSession, require_role
from app.models.event import Event
from app.models.ticket import UserEventDiscount
from app.models.user import User, UserRole
from app.schemas import (
    AdminEventItem,
    AdminStats,
    AdminUserItem,
    AdminTicketItem,
    AdminPledgeItem,
    ApproveBody,
    PlatformSettingItem,
    PlatformSettingUpdate,
)
from app.schemas.admin import (
    AdminUserDetailResponse,
    AdminUserDetailTicketItem,
    AdminUserDetailPledgeItem,
    AdminUserDetailEventItem,
    AdminUserDetailSponsorItem,
    AdminUserDetailDiscountItem,
    AdminSponsorshipBidItem,
    AdminSponsorshipEventItem,
)
from app.services import admin as admin_service
from app.services import platform_settings as settings_service
from app.services import notification_service as notif_svc
from app.services import ticket as ticket_service
from app.services import funding as funding_service
from app.models.notification import NotificationType

router = APIRouter()


@router.get("/users")
async def admin_list_users(
    db: ReadDbSession,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List all users (admin only) with pagination + search."""
    users, total = await admin_service.list_users(db, offset=offset, limit=limit, search=search)
    return {
        "items": [
            AdminUserItem(
                id=u.id,
                email=u.email,
                display_name=u.display_name,
                role=u.role.value,
                created_at=u.created_at,
            )
            for u in users
        ],
        "total": total,
        "offset": offset,
        "limit": limit,
    }


@router.get("/users/{user_id}/detail", response_model=AdminUserDetailResponse)
async def admin_get_user_detail(
    user_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Get role-based user detail (tickets, pledges, events, sponsors, etc.)."""
    from app.core.exceptions import NotFoundError
    from app.services import event as event_service
    from app.services import ticket as ticket_service
    from app.services import funding as funding_service
    from app.services import sponsor as sponsor_svc

    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise NotFoundError("User", user_id)

    base = {
        "id": user.id,
        "email": user.email,
        "display_name": user.display_name,
        "role": user.role.value,
        "created_at": user.created_at,
    }

    if user.role == UserRole.customer:
        from app.models.registration import Registration, RegistrationStatus

        tickets = await ticket_service.list_tickets_for_user_admin(db, user_id=user_id)
        pledges = await funding_service.list_pledges_by_user(db, user_id=user_id, limit=200)
        events_q = (
            select(Event)
            .join(Registration, Registration.event_id == Event.id)
            .where(
                Registration.user_id == user_id,
                Registration.status.in_([RegistrationStatus.registered, RegistrationStatus.waitlist]),
            )
            .options(
                selectinload(Event.venue),
                selectinload(Event.ticket_strategy),
                selectinload(Event.ticket_tiers),
                selectinload(Event.milestones),
                selectinload(Event.sponsorship_categories),
            )
            .order_by(Event.created_at.desc())
            .limit(100)
        )
        events = list((await db.execute(events_q)).scalars().unique().all())

        # Per-event ticket/pledge/donation counts for this customer
        ticket_counts: dict[int, int] = {}
        for t in tickets:
            ticket_counts[t.event_id] = ticket_counts.get(t.event_id, 0) + 1
        pledge_counts: dict[int, int] = {}
        pledge_totals: dict[int, int] = {}
        reserved_spots: dict[int, int] = {}
        donation_counts: dict[int, int] = {}
        donation_totals: dict[int, int] = {}
        for p in pledges:
            if getattr(p, "is_guest", False):
                donation_counts[p.event_id] = donation_counts.get(p.event_id, 0) + 1
                donation_totals[p.event_id] = donation_totals.get(p.event_id, 0) + p.amount_cents
            else:
                pledge_counts[p.event_id] = pledge_counts.get(p.event_id, 0) + 1
                pledge_totals[p.event_id] = pledge_totals.get(p.event_id, 0) + p.amount_cents
                spots = getattr(p, "reserved_spots", 0) or 0
                reserved_spots[p.event_id] = reserved_spots.get(p.event_id, 0) + spots

        return AdminUserDetailResponse(
            **base,
            tickets=[
                AdminUserDetailTicketItem(
                    id=t.id,
                    event_id=t.event_id,
                    event_title=t.event.title if t.event else None,
                    tier_name=t.ticket_tier.name if t.ticket_tier else None,
                    amount_paid_cents=t.amount_paid_cents,
                    status=t.status.value,
                    created_at=t.created_at,
                )
                for t in tickets
            ],
            pledges=[
                AdminUserDetailPledgeItem(
                    id=p.id,
                    event_id=p.event_id,
                    event_title=p.event.title if p.event else None,
                    user_display_name=user.display_name,
                    amount_cents=p.amount_cents,
                    status=p.status.value,
                    is_guest=getattr(p, "is_guest", False),
                    reserved_spots=getattr(p, "reserved_spots", 0) or 0,
                    created_at=p.created_at,
                )
                for p in pledges
            ],
            events=[
                AdminUserDetailEventItem(
                    id=e.id,
                    title=e.title,
                    status=e.status.value,
                    organizer_id=e.organizer_id,
                    description=e.description,
                    genre=e.genre,
                    max_capacity=e.max_capacity,
                    registration_type=e.registration_type.value if e.registration_type else None,
                    registration_count=e.registration_count or 0,
                    funding_goal_cents=e.funding_goal_cents,
                    min_pledge_cents=e.min_pledge_cents or 0,
                    ticket_strategy_name=e.ticket_strategy.name if e.ticket_strategy else None,
                    venue_name=e.venue.name if e.venue else None,
                    venue_address=f"{e.venue.address}, {e.venue.city}" if e.venue and e.venue.address else (e.venue.name if e.venue else None),
                    created_at=e.created_at,
                    start_time=e.start_time,
                    end_time=e.end_time,
                    funding_end_at=e.funding_end_at,
                    has_schedule=e.has_schedule or False,
                    community_rules=e.community_rules or False,
                    ticket_tiers_count=len(e.ticket_tiers) if e.ticket_tiers else 0,
                    sponsorship_categories_count=len(e.sponsorship_categories) if e.sponsorship_categories else 0,
                    milestones_count=len(e.milestones) if e.milestones else 0,
                    user_ticket_count=ticket_counts.get(e.id, 0),
                    user_pledge_count=pledge_counts.get(e.id, 0),
                    user_pledge_total_cents=pledge_totals.get(e.id, 0),
                    user_reserved_spots=reserved_spots.get(e.id, 0),
                    user_donation_count=donation_counts.get(e.id, 0),
                    user_donation_total_cents=donation_totals.get(e.id, 0),
                )
                for e in events
            ],
        )

    if user.role == UserRole.organizer:
        from app.models.escrow import FundEscrow
        from app.models.sponsor import SponsorBid, SponsorshipCategory as SpCat, BidStatus
        from app.services.admin import compute_event_warnings
        from collections import defaultdict

        events_q = (
            select(Event)
            .where(Event.organizer_id == user_id)
            .options(
                selectinload(Event.venue),
                selectinload(Event.ticket_strategy),
                selectinload(Event.ticket_tiers),
                selectinload(Event.milestones),
                selectinload(Event.sponsorship_categories),
            )
            .order_by(Event.created_at.desc())
            .limit(200)
        )
        events = list((await db.execute(events_q)).scalars().unique().all())

        ticket_sales = await ticket_service.list_organizer_ticket_sales(
            db, organizer_id=user_id, limit=200
        )
        pledges = await funding_service.list_organizer_pledges(
            db, organizer_id=user_id, limit=200
        )
        sponsors = await sponsor_svc.get_organizer_sponsors(db, organizer_id=user_id, limit=100)
        discounts_q = (
            select(UserEventDiscount)
            .join(Event, UserEventDiscount.event_id == Event.id)
            .where(Event.organizer_id == user_id)
            .options(
                selectinload(UserEventDiscount.event),
                selectinload(UserEventDiscount.user),
            )
        )
        discounts_res = await db.execute(discounts_q)
        discounts = list(discounts_res.scalars().unique().all())

        # Sponsor bids on this organizer's events
        event_ids = [e.id for e in events]
        sponsor_bids_list: list[AdminSponsorshipEventItem] = []
        if event_ids:
            bids_q = (
                select(
                    SpCat.id.label("cat_id"),
                    SpCat.name.label("cat_name"),
                    SpCat.event_id,
                    SponsorBid.id.label("bid_id"),
                    SponsorBid.amount_cents,
                    SponsorBid.status,
                    SponsorBid.sponsor_user_id,
                )
                .join(SponsorBid, SponsorBid.category_id == SpCat.id)
                .where(
                    SpCat.event_id.in_(event_ids),
                    SponsorBid.status.in_([BidStatus.pending, BidStatus.accepted, BidStatus.paid]),
                )
                .order_by(SpCat.event_id)
            )
            bid_rows = (await db.execute(bids_q)).all()
            events_by_id = {e.id: e for e in events}
            grouped: dict[int, list] = defaultdict(list)
            for r in bid_rows:
                grouped[r.event_id].append(
                    AdminSponsorshipBidItem(
                        bid_id=r.bid_id,
                        category_id=r.cat_id,
                        category_name=r.cat_name,
                        amount_cents=r.amount_cents,
                        status=r.status.value if hasattr(r.status, "value") else str(r.status),
                        can_refund=r.status == BidStatus.paid,
                    )
                )
            for eid, bids in grouped.items():
                evt = events_by_id.get(eid)
                sponsor_bids_list.append(
                    AdminSponsorshipEventItem(
                        event_id=eid,
                        event_title=evt.title if evt else None,
                        bids=bids,
                    )
                )

        # Escrows for this organizer's events (title from already-loaded events)
        escrows_list: list[dict] = []
        if event_ids:
            event_title_map = {e.id: e.title for e in events}
            escrow_q = (
                select(FundEscrow)
                .where(FundEscrow.event_id.in_(event_ids))
                .order_by(FundEscrow.updated_at.desc())
            )
            escrow_rows = (await db.execute(escrow_q)).scalars().all()
            for esc in escrow_rows:
                total_released = esc.stage1_released_cents + esc.stage2_released_cents + esc.stage3_released_cents
                escrows_list.append({
                    "id": esc.id,
                    "event_id": esc.event_id,
                    "event_title": event_title_map.get(esc.event_id),
                    "organizer_name": user.display_name,
                    "organizer_email": user.email,
                    "total_held_cents": esc.total_held_cents,
                    "total_released_cents": total_released,
                    "remaining_cents": max(0, esc.total_held_cents - total_released),
                    "status": esc.status.value,
                    "stage1_released_at": esc.stage1_released_at.isoformat() if esc.stage1_released_at else None,
                    "stage2_released_at": esc.stage2_released_at.isoformat() if esc.stage2_released_at else None,
                    "stage3_released_at": esc.stage3_released_at.isoformat() if esc.stage3_released_at else None,
                })

        return AdminUserDetailResponse(
            **base,
            events=[
                AdminUserDetailEventItem(
                    id=e.id,
                    title=e.title,
                    status=e.status.value,
                    organizer_id=e.organizer_id,
                    description=e.description,
                    genre=e.genre,
                    max_capacity=e.max_capacity,
                    registration_type=e.registration_type.value if e.registration_type else None,
                    registration_count=e.registration_count or 0,
                    funding_goal_cents=e.funding_goal_cents,
                    min_pledge_cents=e.min_pledge_cents or 0,
                    ticket_strategy_name=e.ticket_strategy.name if e.ticket_strategy else None,
                    venue_name=e.venue.name if e.venue else None,
                    venue_address=f"{e.venue.address}, {e.venue.city}" if e.venue and e.venue.address else (e.venue.name if e.venue else None),
                    review_notes=e.review_notes,
                    review_log=e.review_log or [],
                    validation_warnings=compute_event_warnings(e),
                    cancellation_reason=e.cancellation_reason,
                    pending_extension=e.pending_extension,
                    pending_cancellation=e.pending_cancellation,
                    created_at=e.created_at,
                    start_time=e.start_time,
                    end_time=e.end_time,
                    funding_end_at=e.funding_end_at,
                    has_schedule=e.has_schedule or False,
                    community_rules=e.community_rules or False,
                    ticket_tiers_count=len(e.ticket_tiers) if e.ticket_tiers else 0,
                    sponsorship_categories_count=len(e.sponsorship_categories) if e.sponsorship_categories else 0,
                    milestones_count=len(e.milestones) if e.milestones else 0,
                )
                for e in events
            ],
            ticket_sales=[
                AdminUserDetailTicketItem(
                    id=s.id,
                    event_id=s.event_id,
                    event_title=s.event.title if s.event else None,
                    tier_name=s.ticket_tier.name if s.ticket_tier else None,
                    amount_paid_cents=s.amount_paid_cents,
                    status=s.status.value,
                    created_at=s.created_at,
                    attendee_display_name=s.user.display_name if s.user else None,
                )
                for s in ticket_sales
            ],
            pledges=[
                AdminUserDetailPledgeItem(
                    id=p.id,
                    event_id=p.event_id,
                    event_title=p.event.title if p.event else None,
                    user_display_name=p.user.display_name if p.user else None,
                    amount_cents=p.amount_cents,
                    status=p.status.value,
                    is_guest=getattr(p, "is_guest", False),
                    reserved_spots=getattr(p, "reserved_spots", 0) or 0,
                    created_at=p.created_at,
                )
                for p in pledges
            ],
            sponsors=[
                AdminUserDetailSponsorItem(
                    sponsor_user_id=s["sponsor_user_id"],
                    company_name=s.get("company_name"),
                    contact_name=s.get("contact_name"),
                    total_bids=s.get("total_bids", 0),
                    total_amount_cents=s.get("total_amount_cents", 0),
                )
                for s in sponsors
            ],
            discounts=[
                AdminUserDetailDiscountItem(
                    event_id=d.event_id,
                    event_title=d.event.title if d.event else None,
                    user_id=d.user_id,
                    user_display_name=d.user.display_name if d.user else None,
                    discount_type=d.discount_type,
                    value=d.value,
                )
                for d in discounts
            ],
            sponsor_bids=sponsor_bids_list if sponsor_bids_list else None,
            escrows=escrows_list if escrows_list else None,
        )

    if user.role == UserRole.sponsor:
        sponsorships = await sponsor_svc.get_sponsor_bids_detail_for_admin(db, sponsor_user_id=user_id)
        tickets = await ticket_service.list_tickets_for_user_admin(db, user_id=user_id)
        pledges = await funding_service.list_pledges_by_user(db, user_id=user_id, limit=200)
        return AdminUserDetailResponse(
            **base,
            sponsorships=[
                AdminSponsorshipEventItem(
                    event_id=sp["event_id"],
                    event_title=sp["event_title"],
                    bids=[
                        AdminSponsorshipBidItem(
                            bid_id=b["bid_id"],
                            category_id=b["category_id"],
                            category_name=b["category_name"],
                            amount_cents=b["amount_cents"],
                            status=b["status"],
                            can_refund=b["can_refund"],
                        )
                        for b in sp["bids"]
                    ],
                )
                for sp in sponsorships
            ],
            tickets=[
                AdminUserDetailTicketItem(
                    id=t.id,
                    event_id=t.event_id,
                    event_title=t.event.title if t.event else None,
                    tier_name=t.ticket_tier.name if t.ticket_tier else None,
                    amount_paid_cents=t.amount_paid_cents,
                    status=t.status.value,
                    created_at=t.created_at,
                )
                for t in tickets
            ],
            pledges=[
                AdminUserDetailPledgeItem(
                    id=p.id,
                    event_id=p.event_id,
                    event_title=p.event.title if p.event else None,
                    user_display_name=user.display_name,
                    amount_cents=p.amount_cents,
                    status=p.status.value,
                    is_guest=getattr(p, "is_guest", False),
                    reserved_spots=getattr(p, "reserved_spots", 0) or 0,
                    created_at=p.created_at,
                )
                for p in pledges
            ],
        )

    return AdminUserDetailResponse(**base)


@router.get("/events")
async def admin_list_events(
    db: ReadDbSession,
    status: str | None = None,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List events for admin with validation warnings and review log."""
    events, total = await admin_service.list_events_for_admin(
        db, status=status, offset=offset, limit=limit, search=search,
    )
    items = []
    for e in events:
        item = {
            "id": e.id,
            "title": e.title,
            "status": e.status.value,
            "organizer_id": e.organizer_id,
            "max_capacity": e.max_capacity,
            "funding_goal_cents": e.funding_goal_cents,
            "review_notes": e.review_notes,
            "review_log": e.review_log or [],
            "cancellation_reason": e.cancellation_reason,
            "pending_extension": e.pending_extension,
            "pending_cancellation": e.pending_cancellation,
            "created_at": e.created_at.isoformat() if e.created_at else None,
            "start_time": e.start_time.isoformat() if e.start_time else None,
            "end_time": e.end_time.isoformat() if e.end_time else None,
            "funding_end_at": e.funding_end_at.isoformat() if e.funding_end_at else None,
            "validation_warnings": admin_service.compute_event_warnings(e),
        }
        items.append(item)
    return {"items": items, "total": total, "offset": offset, "limit": limit}


@router.post("/events/{event_id}/approve")
async def approve_event(
    event_id: int,
    body: ApproveBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Approve or reject event (admin). Approved -> status approved; reject -> back to draft."""
    event = await admin_service.approve_or_reject_event(
        db, event_id=event_id, approved=body.approved
    )
    if body.approved:
        await notif_svc.create_notification(
            db, user_id=event.organizer_id,
            type=NotificationType.event_approved,
            title="Event Approved",
            message=f'Your event "{event.title}" has been approved.',
            data={"event_id": event.id},
        )
    else:
        await notif_svc.create_notification(
            db, user_id=event.organizer_id,
            type=NotificationType.event_rejected,
            title="Event Rejected",
            message=f'Your event "{event.title}" was not approved.',
            data={"event_id": event.id},
        )
    return {"ok": True, "event_id": event.id, "status": event.status.value}


@router.get("/stats", response_model=AdminStats)
async def admin_stats(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Platform stats including commission totals."""
    stats = await admin_service.get_stats(db)
    return AdminStats(**stats)


@router.get("/dashboard")
async def admin_dashboard(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    period: str = Query("30d"),
    genre: str | None = Query(None),
    status: str | None = Query(None),
):
    """Consolidated dashboard data for admin home tab."""
    data = await admin_service.get_dashboard(
        db, period=period, genre=genre, status=status,
    )
    return data


# ----- Platform Settings -----
@router.get("/settings", response_model=list[PlatformSettingItem])
async def get_settings(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List all platform settings (admin only)."""
    rows = await settings_service.get_all_with_descriptions(db)
    return [PlatformSettingItem(**r) for r in rows]


@router.patch("/settings/{key}")
async def update_setting(
    key: str,
    body: PlatformSettingUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Update a platform setting by key (admin only)."""
    setting = await settings_service.set_value(db, key, body.value)
    from app.api.v1.config import invalidate_public_config
    await invalidate_public_config()
    if key.startswith("rate_limit_"):
        from app.rate_limit import reload_rate_limits
        await reload_rate_limits(db)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="settings_update",
        target_type="setting", target_id=key, details={"value": body.value},
    )
    return PlatformSettingItem(key=setting.key, value=setting.value, description=setting.description)


# ----- Escrow Management (Admin) -----
from app.services import escrow as escrow_service


@router.get("/tickets")
async def admin_list_tickets(
    db: ReadDbSession,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None),
    status: str | None = Query(None),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List ticket sales for admin, optionally filtered by status."""
    sales, total = await ticket_service.list_all_ticket_sales_for_admin(
        db, offset=offset, limit=limit, search=search, status=status,
    )
    return {
        "items": [
            AdminTicketItem(
                id=s.id,
                event_id=s.event_id,
                event_title=s.event.title if s.event else None,
                user_id=s.user_id,
                attendee_display_name=s.user.display_name if s.user else None,
                tier_name=s.ticket_tier.name if s.ticket_tier else None,
                amount_paid_cents=s.amount_paid_cents,
                status=s.status.value,
                created_at=s.created_at,
            )
            for s in sales
        ],
        "total": total,
        "offset": offset,
        "limit": limit,
    }


@router.get("/pledges")
async def admin_list_pledges(
    db: ReadDbSession,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None),
    status: str | None = Query(None),
    is_donation: bool | None = Query(None),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List pledges across events for admin, optionally filtered by status/donation."""
    pledges, total = await funding_service.list_all_pledges_for_admin(
        db, offset=offset, limit=limit, search=search, status=status, is_donation=is_donation,
    )
    return {
        "items": [
            AdminPledgeItem(
                id=p.id,
                event_id=p.event_id,
                event_title=p.event.title if p.event else None,
                user_id=p.user_id,
                user_display_name=p.user.display_name if p.user else None,
                amount_cents=p.amount_cents,
                status=p.status.value,
                is_guest=p.is_guest,
                created_at=p.created_at,
            )
            for p in pledges
        ],
        "total": total,
        "offset": offset,
        "limit": limit,
    }


@router.post("/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/refund")
async def admin_refund_sponsor_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin refund a paid sponsor bid."""
    from app.services import sponsor as sponsor_svc
    from app.services import notification_service as notif_svc
    from app.models.notification import NotificationType
    from app.models.sponsor import SponsorBid
    payment = await sponsor_svc.refund_bid(db, bid_id, current_user)
    bid_obj = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    sponsor_user_id = bid_obj.sponsor_user_id if bid_obj else None
    if sponsor_user_id:
        await notif_svc.create_notification(
            db, user_id=sponsor_user_id,
            type=NotificationType.sponsor_refunded,
            title="Sponsorship Refunded",
            message="Your sponsorship payment has been refunded by an administrator.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id, "payment_id": payment.id},
        )
    return {"ok": True, "event_id": event_id, "bid_id": bid_id, "payment_id": payment.id}


@router.post("/events/{event_id}/pledges/{funding_id}/refund")
async def admin_refund_pledge(
    event_id: int,
    funding_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin refund a single pledge by id."""
    count = await funding_service.refund_pledge_by_id(db, event_id=event_id, funding_id=funding_id)
    if count == 0:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Pledge", funding_id)
    return {"ok": True, "event_id": event_id, "funding_id": funding_id}


@router.get("/escrows")
async def list_escrows(
    db: ReadDbSession,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List all fund escrows (admin only) with pagination + search."""
    items, total = await escrow_service.list_all_escrows(
        db, offset=offset, limit=limit, search=search,
    )
    return {"items": items, "total": total, "offset": offset, "limit": limit}


@router.post("/escrows/{event_id}/release/{stage}")
async def admin_release_stage(
    event_id: int,
    stage: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin manually releases a specific fund escrow stage. Enqueues ARQ task for payment."""
    if stage == 1:
        escrow = await escrow_service.release_stage1(db, event_id=event_id, released_by="admin")
    elif stage == 2:
        escrow = await escrow_service.release_stage2(db, event_id=event_id, released_by="admin")
    elif stage == 3:
        escrow = await escrow_service.release_stage3(db, event_id=event_id, released_by="admin")
    else:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Stage must be 1, 2, or 3")

    from app.worker.redis_pool import enqueue
    await enqueue("process_escrow_release", "fund", escrow.id, stage)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_release",
        target_type="fund_escrow", target_id=event_id, details={"stage": stage},
    )
    return await escrow_service.get_escrow_summary(db, event_id=event_id)


@router.post("/escrows/{event_id}/freeze")
async def freeze_escrow(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin freezes an event's escrow payouts."""
    await escrow_service.freeze(db, event_id=event_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_freeze",
        target_type="fund_escrow", target_id=event_id,
    )
    return await escrow_service.get_escrow_summary(db, event_id=event_id)


@router.post("/escrows/{event_id}/unfreeze")
async def unfreeze_escrow(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin unfreezes an event's escrow payouts."""
    await escrow_service.unfreeze(db, event_id=event_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_unfreeze",
        target_type="fund_escrow", target_id=event_id,
    )
    return await escrow_service.get_escrow_summary(db, event_id=event_id)


# ----- Ticket Escrow Management -----
from app.services import ticket_escrow as te_svc
from app.services import sponsor_escrow as se_svc


def _escrow_to_dict(e) -> dict:
    released = e.stage1_released_cents + e.stage2_released_cents + e.stage3_released_cents
    return {
        "id": e.id, "event_id": e.event_id,
        "total_held_cents": e.total_held_cents, "total_released_cents": released,
        "remaining_cents": max(0, e.total_held_cents - released),
        "status": e.status.value,
        "stage1_released_cents": e.stage1_released_cents,
        "stage1_released_at": e.stage1_released_at.isoformat() if e.stage1_released_at else None,
        "stage1_auto_release": e.stage1_auto_release,
        "stage2_released_cents": e.stage2_released_cents,
        "stage2_released_at": e.stage2_released_at.isoformat() if e.stage2_released_at else None,
        "stage2_auto_release": e.stage2_auto_release,
        "stage3_released_cents": e.stage3_released_cents,
        "stage3_released_at": e.stage3_released_at.isoformat() if e.stage3_released_at else None,
        "stage3_auto_release": e.stage3_auto_release,
    }


@router.get("/ticket-escrows")
async def list_ticket_escrows(
    db: ReadDbSession,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    items, total = await te_svc.list_all(db, offset=offset, limit=limit, search=search)
    return {"items": items, "total": total}


@router.post("/ticket-escrows/{event_id}/release/{stage}")
async def admin_release_ticket_stage(
    event_id: int, stage: int, db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    if stage == 1:
        await te_svc.release_stage1(db, event_id=event_id, released_by="admin")
    elif stage == 2:
        await te_svc.release_stage2(db, event_id=event_id, released_by="admin")
    elif stage == 3:
        await te_svc.release_stage3(db, event_id=event_id, released_by="admin")
    else:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Stage must be 1, 2, or 3")
    escrow = await te_svc.get_or_create(db, event_id=event_id)

    from app.worker.redis_pool import enqueue
    await enqueue("process_escrow_release", "ticket", escrow.id, stage)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_release",
        target_type="ticket_escrow", target_id=event_id, details={"stage": stage},
    )
    return _escrow_to_dict(escrow)


@router.post("/ticket-escrows/{event_id}/freeze")
async def freeze_ticket_escrow(
    event_id: int, db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    escrow = await te_svc.freeze(db, event_id=event_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_freeze",
        target_type="ticket_escrow", target_id=event_id,
    )
    return _escrow_to_dict(escrow)


@router.post("/ticket-escrows/{event_id}/unfreeze")
async def unfreeze_ticket_escrow(
    event_id: int, db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    escrow = await te_svc.unfreeze(db, event_id=event_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_unfreeze",
        target_type="ticket_escrow", target_id=event_id,
    )
    return _escrow_to_dict(escrow)


# ----- Sponsor Escrow Management -----

@router.get("/sponsor-escrows")
async def list_sponsor_escrows(
    db: ReadDbSession,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    items, total = await se_svc.list_all(db, offset=offset, limit=limit, search=search)
    return {"items": items, "total": total}


@router.post("/sponsor-escrows/{event_id}/release/{stage}")
async def admin_release_sponsor_stage(
    event_id: int, stage: int, db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    if stage == 1:
        await se_svc.release_stage1(db, event_id=event_id, released_by="admin")
    elif stage == 2:
        await se_svc.release_stage2(db, event_id=event_id, released_by="admin")
    elif stage == 3:
        await se_svc.release_stage3(db, event_id=event_id, released_by="admin")
    else:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Stage must be 1, 2, or 3")
    escrow = await se_svc.get_or_create(db, event_id=event_id)

    from app.worker.redis_pool import enqueue
    await enqueue("process_escrow_release", "sponsor", escrow.id, stage)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_release",
        target_type="sponsor_escrow", target_id=event_id, details={"stage": stage},
    )
    return _escrow_to_dict(escrow)


@router.post("/sponsor-escrows/{event_id}/freeze")
async def freeze_sponsor_escrow(
    event_id: int, db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    escrow = await se_svc.freeze(db, event_id=event_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_freeze",
        target_type="sponsor_escrow", target_id=event_id,
    )
    return _escrow_to_dict(escrow)


@router.post("/sponsor-escrows/{event_id}/unfreeze")
async def unfreeze_sponsor_escrow(
    event_id: int, db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    escrow = await se_svc.unfreeze(db, event_id=event_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_unfreeze",
        target_type="sponsor_escrow", target_id=event_id,
    )
    return _escrow_to_dict(escrow)


# ----- Per-escrow auto-release toggles -----

class _AutoReleaseBody(_BaseModel):
    stage1_auto_release: bool | None = None
    stage2_auto_release: bool | None = None
    stage3_auto_release: bool | None = None


@router.patch("/{escrow_type}-escrows/{event_id}/auto-release")
async def toggle_auto_release(
    escrow_type: str,
    event_id: int,
    body: _AutoReleaseBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Toggle per-stage auto-release for a specific escrow record."""
    from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow

    model_map = {"fund": FundEscrow, "ticket": TicketEscrow, "sponsor": SponsorEscrow}
    svc_map = {"fund": escrow_service, "ticket": te_svc, "sponsor": se_svc}
    model_cls = model_map.get(escrow_type)
    svc = svc_map.get(escrow_type)
    if not model_cls or not svc:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="escrow_type must be fund, ticket, or sponsor")

    escrow = await svc.get_or_create(db, event_id=event_id)
    changed = {}
    for field in ("stage1_auto_release", "stage2_auto_release", "stage3_auto_release"):
        val = getattr(body, field)
        if val is not None:
            setattr(escrow, field, val)
            changed[field] = val
    await db.flush()
    await db.refresh(escrow)

    await audit_svc.log_action(
        db, admin_id=current_user.id, action="escrow_auto_release_toggle",
        target_type=f"{escrow_type}_escrow", target_id=event_id, details=changed,
    )
    return _escrow_to_dict(escrow)


# ----- Unified per-event escrow view -----

@router.get("/escrows/by-event/{event_id}")
async def get_event_escrows(
    event_id: int, db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Return all 3 escrow types for one event."""
    from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow

    fund = (await db.execute(select(FundEscrow).where(FundEscrow.event_id == event_id))).scalar_one_or_none()
    ticket = (await db.execute(select(TicketEscrow).where(TicketEscrow.event_id == event_id))).scalar_one_or_none()
    sponsor = (await db.execute(select(SponsorEscrow).where(SponsorEscrow.event_id == event_id))).scalar_one_or_none()

    return {
        "event_id": event_id,
        "fund": _escrow_to_dict(fund) if fund else None,
        "ticket": _escrow_to_dict(ticket) if ticket else None,
        "sponsor": _escrow_to_dict(sponsor) if sponsor else None,
    }


@router.post("/organizers/{organizer_id}/freeze-payouts")
async def freeze_organizer_payouts(
    organizer_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin freezes all payout for an organizer (sets payout_frozen on all their events)."""
    from app.models.event import Event
    from sqlalchemy import update
    result = await db.execute(
        update(Event)
        .where(Event.organizer_id == organizer_id)
        .values(payout_frozen=True)
    )
    await db.flush()
    return {"ok": True, "events_frozen": result.rowcount or 0}


class ResolveReviewBody(_BaseModel):
    target_status: str
    notes: str | None = None

@router.post("/events/{event_id}/resolve-review")
async def resolve_review(
    event_id: int,
    body: ResolveReviewBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Resolve an under_review event by moving it to the specified status."""
    from app.models.event import Event, EventStatus
    from app.core.exceptions import NotFoundError, ConflictError
    from datetime import datetime, timezone as tz
    event = (await db.execute(
        select(Event).where(Event.id == event_id)
    )).scalar_one_or_none()
    if not event:
        raise NotFoundError("Event", event_id)
    if event.status != EventStatus.under_review:
        raise ConflictError(f"Event is not under review (current: {event.status.value})")
    allowed = {s.value for s in EventStatus} - {"under_review"}
    if body.target_status not in allowed:
        raise ConflictError(f"Invalid target status '{body.target_status}'")
    event.status = EventStatus(body.target_status)
    event.review_notes = body.notes or f"Resolved by admin → {body.target_status}"
    event.review_log = (event.review_log or []) + [{
        "timestamp": datetime.now(tz.utc).isoformat(),
        "actor": f"admin:{current_user.email}",
        "action": "resolved",
        "from_status": "under_review",
        "to_status": body.target_status,
        "message": body.notes or f"Resolved → {body.target_status}",
    }]
    await db.flush()
    notif_msg = f'Your event "{event.title}" has been reviewed and moved to {body.target_status.replace("_", " ")}.'
    if body.notes:
        notif_msg += f" Admin notes: {body.notes}"
    await notif_svc.create_notification(
        db, user_id=event.organizer_id,
        type=NotificationType.event_approved,
        title="Event Review Resolved",
        message=notif_msg,
        data={"event_id": event.id},
    )
    return {"ok": True, "event_id": event.id, "status": event.status.value}


# ----- Audit Log -----

@router.get("/audit-log")
async def get_audit_log(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    action: str | None = Query(None),
    target_type: str | None = Query(None),
    admin_id: int | None = Query(None),
):
    """Paginated audit log of admin actions."""
    rows, total = await audit_svc.list_audit_logs(
        db, offset=offset, limit=limit,
        action=action, target_type=target_type, admin_id=admin_id,
    )
    return {
        "items": [
            {
                "id": r.id,
                "admin_id": r.admin_id,
                "action": r.action,
                "target_type": r.target_type,
                "target_id": r.target_id,
                "details": r.details,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ],
        "total": total,
        "offset": offset,
        "limit": limit,
    }


# ----- ARQ Worker Run Logs -----

@router.get("/worker-runs")
async def list_worker_runs(
    db: ReadDbSession,
    task_name: str | None = Query(None, description="Filter by task name"),
    status: str | None = Query(None, description="Filter by status (success/error/skipped)"),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List ARQ cron job run logs with optional filters."""
    from sqlalchemy import func
    from app.models.worker_run_log import WorkerRunLog

    conditions = []
    if task_name:
        conditions.append(WorkerRunLog.task_name == task_name)
    if status:
        conditions.append(WorkerRunLog.status == status)

    count_q = select(func.count(WorkerRunLog.id))
    if conditions:
        count_q = count_q.where(*conditions)
    total = (await db.execute(count_q)).scalar() or 0

    q = (
        select(WorkerRunLog)
        .order_by(WorkerRunLog.started_at.desc())
        .offset(offset)
        .limit(limit)
    )
    if conditions:
        q = q.where(*conditions)
    rows = (await db.execute(q)).scalars().all()

    return {
        "items": [
            {
                "id": r.id,
                "task_name": r.task_name,
                "status": r.status,
                "duration_ms": r.duration_ms,
                "items_processed": r.items_processed,
                "error": r.error,
                "started_at": r.started_at.isoformat() if r.started_at else None,
                "finished_at": r.finished_at.isoformat() if r.finished_at else None,
            }
            for r in rows
        ],
        "total": total,
        "offset": offset,
        "limit": limit,
    }


@router.get("/worker-summary")
async def worker_summary(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Summary of each cron job: last run time, last status, total runs, total errors."""
    from sqlalchemy import func, case
    from app.models.worker_run_log import WorkerRunLog

    q = (
        select(
            WorkerRunLog.task_name,
            func.count(WorkerRunLog.id).label("total_runs"),
            func.count(case((WorkerRunLog.status == "error", 1))).label("total_errors"),
            func.max(WorkerRunLog.started_at).label("last_run_at"),
        )
        .group_by(WorkerRunLog.task_name)
    )
    rows = (await db.execute(q)).all()

    task_names = [
        "mock_auto_settle",
        "check_all_ticket_escrows",
        "check_all_sponsor_escrows",
        "process_scheduled_payouts",
        "daily_reconciliation",
    ]

    setting_keys = {
        "mock_auto_settle": "arq_mock_auto_settle_enabled",
        "check_all_ticket_escrows": "arq_ticket_escrow_check_enabled",
        "check_all_sponsor_escrows": "arq_sponsor_escrow_check_enabled",
        "process_scheduled_payouts": "arq_scheduled_payouts_enabled",
        "daily_reconciliation": "arq_daily_reconciliation_enabled",
    }

    by_name = {r.task_name: r for r in rows}

    last_status_q = (
        select(WorkerRunLog.task_name, WorkerRunLog.status)
        .distinct(WorkerRunLog.task_name)
        .order_by(WorkerRunLog.task_name, WorkerRunLog.started_at.desc())
    )
    last_rows = (await db.execute(last_status_q)).all()
    last_status_map = {r.task_name: r.status for r in last_rows}

    enabled_map = {}
    for tn, sk in setting_keys.items():
        enabled_map[tn] = await settings_service.get_bool(db, sk)

    items = []
    for tn in task_names:
        r = by_name.get(tn)
        items.append({
            "task_name": tn,
            "enabled": enabled_map.get(tn, True),
            "setting_key": setting_keys[tn],
            "total_runs": r.total_runs if r else 0,
            "total_errors": r.total_errors if r else 0,
            "last_run_at": r.last_run_at.isoformat() if r and r.last_run_at else None,
            "last_status": last_status_map.get(tn),
        })

    return {"tasks": items}
