"""
Sponsor marketplace API endpoints.
"""
from fastapi import APIRouter, Depends, Form, HTTPException, Query, UploadFile, File
from sqlalchemy import select

from app.dependencies import DbSession, CurrentUser, CurrentUserOptional, require_feature
from app.models.user import UserRole
from app.schemas.sponsor import (
    SponsorProfileCreate,
    SponsorProfileUpdate,
    SponsorProfileResponse,
    CategoryCreate,
    CategoryUpdate,
    CategoryResponse,
    BidCreate,
    BidUpdate,
    BidResponse,
    PaymentResponse,
    SponsorTicketResponse,
)
from app.services import sponsor as sponsor_svc
from app.services import notification_service as notif_svc
from app.models.notification import NotificationType

router = APIRouter()

_feature_guard = require_feature("feature_sponsors_enabled")


# ── Sponsor Profile ──

@router.post(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def create_sponsor_profile(
    data: SponsorProfileCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    profile = await sponsor_svc.create_profile(db, current_user, data)
    await db.commit()
    await db.refresh(profile)
    return profile


@router.get(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
    dependencies=[Depends(_feature_guard)],
)
async def get_sponsor_profile(db: DbSession, current_user: CurrentUser):
    profile = await sponsor_svc.get_profile(db, current_user.id)
    if not profile:
        raise HTTPException(status_code=404, detail="Sponsor profile not found")
    return profile


@router.patch(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
    dependencies=[Depends(_feature_guard)],
)
async def update_sponsor_profile(
    data: SponsorProfileUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    profile = await sponsor_svc.update_profile(db, current_user.id, data)
    await db.commit()
    await db.refresh(profile)
    return profile


# ── Sponsor Category Templates ──

def _template_to_response(cat) -> dict:
    return {
        "id": cat.id,
        "organizer_id": cat.organizer_id,
        "is_template": cat.is_template,
        "name": cat.name,
        "description": cat.description,
        "image_url": cat.image_url,
        "total_spots": cat.total_spots,
        "min_bid_cents": cat.min_bid_cents,
        "sort_order": cat.sort_order,
    }


@router.get(
    "/me/sponsor-category-templates",
    dependencies=[Depends(_feature_guard)],
)
async def list_templates(db: DbSession, current_user: CurrentUser):
    templates = await sponsor_svc.list_templates(db, current_user)
    return [_template_to_response(t) for t in templates]


@router.post(
    "/me/sponsor-category-templates",
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def create_template(
    data: CategoryCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.create_template(db, current_user, data)
    await db.commit()
    await db.refresh(cat)
    return _template_to_response(cat)


@router.patch(
    "/me/sponsor-category-templates/{template_id}",
    dependencies=[Depends(_feature_guard)],
)
async def update_template(
    template_id: int,
    data: CategoryUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.update_template(db, template_id, current_user, data)
    await db.commit()
    await db.refresh(cat)
    return _template_to_response(cat)


@router.delete(
    "/me/sponsor-category-templates/{template_id}",
    status_code=204,
    dependencies=[Depends(_feature_guard)],
)
async def delete_template(
    template_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    await sponsor_svc.delete_template(db, template_id, current_user)
    await db.commit()


@router.post(
    "/events/{event_id}/sponsorships/from-template/{template_id}",
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def copy_template_to_event(
    event_id: int,
    template_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.copy_template_to_event(db, template_id, event_id, current_user)
    await db.commit()
    await db.refresh(cat)
    return {
        "id": cat.id,
        "event_id": cat.event_id,
        "name": cat.name,
        "description": cat.description,
        "total_spots": cat.total_spots,
        "min_bid_cents": cat.min_bid_cents,
    }


# ── Template Prerequisites ──

@router.get(
    "/me/sponsor-category-templates/{template_id}/prerequisites",
    dependencies=[Depends(_feature_guard)],
)
async def list_template_prerequisites(
    template_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    from app.models.prerequisite import CategoryPrerequisite
    q = select(CategoryPrerequisite).where(CategoryPrerequisite.category_id == template_id)
    items = (await db.execute(q)).scalars().all()
    return [{"id": p.id, "name": p.name, "description": p.description, "is_required": p.is_required, "requires_document": p.requires_document} for p in items]


@router.post(
    "/me/sponsor-category-templates/{template_id}/prerequisites",
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def create_template_prerequisite(
    template_id: int,
    name: str = Form(...),
    description: str | None = Form(None),
    is_required: bool = Form(True),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    from app.models.sponsor import SponsorshipCategory
    from app.models.prerequisite import CategoryPrerequisite
    cat = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != current_user.id and current_user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")
    prereq = CategoryPrerequisite(category_id=template_id, name=name, description=description, is_required=is_required)
    db.add(prereq)
    await db.flush()
    await db.refresh(prereq)
    await db.commit()
    return {"id": prereq.id, "name": prereq.name, "description": prereq.description, "is_required": prereq.is_required}


@router.delete(
    "/me/sponsor-category-templates/{template_id}/prerequisites/{prereq_id}",
    status_code=204,
    dependencies=[Depends(_feature_guard)],
)
async def delete_template_prerequisite(
    template_id: int,
    prereq_id: int,
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    from app.models.sponsor import SponsorshipCategory
    from app.models.prerequisite import CategoryPrerequisite
    cat = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != current_user.id and current_user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")
    prereq = (await db.execute(
        select(CategoryPrerequisite).where(CategoryPrerequisite.id == prereq_id, CategoryPrerequisite.category_id == template_id)
    )).scalar_one_or_none()
    if not prereq:
        raise HTTPException(status_code=404, detail="Prerequisite not found")
    await db.delete(prereq)
    await db.commit()


# ── Sponsorship Categories ──

def _category_to_response(cat, bid_count: int = 0, bid_amounts: list[int] | None = None, my_bid_count: int = 0, my_bids: list[dict] | None = None, prereq_count: int = 0) -> dict:
    return {
        "id": cat.id,
        "event_id": cat.event_id,
        "name": cat.name,
        "description": cat.description,
        "image_url": cat.image_url,
        "total_spots": cat.total_spots,
        "filled_spots": cat.filled_spots,
        "min_bid_cents": cat.min_bid_cents,
        "sort_order": cat.sort_order,
        "bid_count": bid_count,
        "bid_amounts": bid_amounts or [],
        "my_bid_count": my_bid_count,
        "my_bids": my_bids or [],
        "prereq_count": prereq_count,
    }


@router.get(
    "/events/{event_id}/sponsorships",
    dependencies=[Depends(_feature_guard)],
)
async def list_categories(
    event_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    if current_user.role not in (UserRole.sponsor, UserRole.organizer, UserRole.admin):
        raise HTTPException(status_code=403, detail="Sponsorship categories are not visible to customers")
    cats = await sponsor_svc.list_categories(db, event_id)
    prereq_counts = await sponsor_svc.get_prereq_counts(db, [c.id for c in cats])
    result = []
    for c in cats:
        count, amounts = await sponsor_svc.get_bid_stats(db, c.id)
        my_count = await sponsor_svc.get_my_bid_count(db, c.id, current_user.id)
        my_bids = await sponsor_svc.get_my_bids(db, c.id, current_user.id)
        result.append(_category_to_response(
            c, bid_count=count, bid_amounts=amounts,
            my_bid_count=my_count, my_bids=my_bids,
            prereq_count=prereq_counts.get(c.id, 0),
        ))
    return result


@router.post(
    "/events/{event_id}/sponsorships",
    response_model=CategoryResponse,
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def create_category(
    event_id: int,
    data: CategoryCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.create_category(db, event_id, current_user, data)
    await db.commit()
    await db.refresh(cat)
    return _category_to_response(cat)


@router.patch(
    "/events/{event_id}/sponsorships/{cat_id}",
    response_model=CategoryResponse,
    dependencies=[Depends(_feature_guard)],
)
async def update_category(
    event_id: int,
    cat_id: int,
    data: CategoryUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.update_category(db, cat_id, current_user, data)
    await db.commit()
    await db.refresh(cat)
    return _category_to_response(cat)


@router.delete(
    "/events/{event_id}/sponsorships/{cat_id}",
    status_code=204,
    dependencies=[Depends(_feature_guard)],
)
async def delete_category(
    event_id: int,
    cat_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    await sponsor_svc.delete_category(db, cat_id, current_user)
    await db.commit()


# ── Bids ──

async def _bid_to_response(db, bid) -> dict:
    profile = await sponsor_svc.get_profile(db, bid.sponsor_user_id)
    if profile:
        profile_data = {
            "id": profile.id,
            "user_id": profile.user_id,
            "company_name": profile.company_name,
            "contact_name": profile.contact_name,
            "profession": profile.profession,
            "logo_url": profile.logo_url,
            "description": profile.description,
            "website_url": profile.website_url,
        }
    else:
        from app.models.user import User
        from sqlalchemy import select
        user = (await db.execute(
            select(User).where(User.id == bid.sponsor_user_id)
        )).scalar_one_or_none()
        fallback_name = user.display_name if user else "Unknown"
        profile_data = {
            "id": 0,
            "user_id": bid.sponsor_user_id,
            "company_name": fallback_name,
            "contact_name": (user.display_name or "") if user else "",
            "profession": "",
        }
    return {
        "id": bid.id,
        "category_id": bid.category_id,
        "sponsor_user_id": bid.sponsor_user_id,
        "amount_cents": bid.amount_cents,
        "proposal_text": bid.proposal_text,
        "status": bid.status.value,
        "sponsor_profile": profile_data,
    }


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids",
    response_model=BidResponse,
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def place_bid(
    event_id: int,
    cat_id: int,
    data: BidCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.place_bid(db, cat_id, current_user, data)
    # Notify event organizer
    from sqlalchemy import select as sel
    from app.models.sponsor import SponsorshipCategory
    from app.models.event import Event
    cat = (await db.execute(sel(SponsorshipCategory).where(SponsorshipCategory.id == cat_id))).scalar_one()
    event = (await db.execute(sel(Event).where(Event.id == cat.event_id))).scalar_one()
    await notif_svc.create_notification(
        db, user_id=event.organizer_id,
        type=NotificationType.bid_received,
        title="New Sponsor Bid",
        message=f"A new bid of ${data.amount_cents / 100:.2f} was placed on '{cat.name}'.",
        data={"event_id": cat.event_id, "category_id": cat_id, "bid_id": bid.id},
    )
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


@router.patch(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}",
    response_model=BidResponse,
    dependencies=[Depends(_feature_guard)],
)
async def update_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    data: BidUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.update_bid(db, bid_id, current_user, data)
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/withdraw",
    response_model=BidResponse,
    dependencies=[Depends(_feature_guard)],
)
async def withdraw_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.withdraw_bid(db, bid_id, current_user)

    from sqlalchemy import select as sa_select
    from app.models.event import Event
    event_obj = (await db.execute(
        sa_select(Event).where(Event.id == event_id)
    )).scalar_one_or_none()
    if event_obj:
        await notif_svc.create_notification(
            db, user_id=event_obj.organizer_id,
            type=NotificationType.bid_rejected,
            title="Bid Withdrawn",
            message=f"A sponsor has withdrawn their bid.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id},
        )

    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


@router.get(
    "/events/{event_id}/sponsorships/{cat_id}/bids",
    response_model=list[BidResponse],
    dependencies=[Depends(_feature_guard)],
)
async def list_bids(
    event_id: int,
    cat_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    bids = await sponsor_svc.list_bids(db, cat_id, current_user)
    return [await _bid_to_response(db, b) for b in bids]


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/accept",
    response_model=BidResponse,
    dependencies=[Depends(_feature_guard)],
)
async def accept_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.accept_bid(db, bid_id, current_user)
    await notif_svc.create_notification(
        db, user_id=bid.sponsor_user_id,
        type=NotificationType.bid_accepted,
        title="Bid Accepted",
        message="Your sponsorship bid has been accepted!",
        data={"event_id": event_id, "category_id": cat_id, "bid_id": bid.id},
    )
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/reject",
    response_model=BidResponse,
    dependencies=[Depends(_feature_guard)],
)
async def reject_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    bid = await sponsor_svc.reject_bid(db, bid_id, current_user)
    await notif_svc.create_notification(
        db, user_id=bid.sponsor_user_id,
        type=NotificationType.bid_rejected,
        title="Bid Rejected",
        message="Your sponsorship bid was not accepted.",
        data={"event_id": event_id, "category_id": cat_id, "bid_id": bid.id},
    )
    await db.commit()
    await db.refresh(bid)
    return await _bid_to_response(db, bid)


# ── Payments ──

@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/pay",
    response_model=PaymentResponse,
    dependencies=[Depends(_feature_guard)],
)
async def pay_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    payment = await sponsor_svc.pay_bid(db, bid_id, current_user)

    from sqlalchemy import select as sa_select
    from app.models.event import Event
    event_obj = (await db.execute(
        sa_select(Event).where(Event.id == event_id)
    )).scalar_one_or_none()
    if event_obj:
        await notif_svc.create_notification(
            db, user_id=event_obj.organizer_id,
            type=NotificationType.sponsor_payment_received,
            title="Sponsor Payment Received",
            message=f"A sponsor has paid ${payment.amount_cents / 100:.2f} for their sponsorship.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id, "payment_id": payment.id},
        )

    await db.commit()
    await db.refresh(payment)
    return payment


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}/refund",
    response_model=PaymentResponse,
    dependencies=[Depends(_feature_guard)],
)
async def refund_bid(
    event_id: int,
    cat_id: int,
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Organizer refunds a paid bid."""
    from sqlalchemy import select as sa_select
    from app.models.sponsor import SponsorBid

    bid_obj = (await db.execute(
        sa_select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    sponsor_user_id = bid_obj.sponsor_user_id if bid_obj else None

    payment = await sponsor_svc.refund_bid(db, bid_id, current_user)

    if sponsor_user_id:
        await notif_svc.create_notification(
            db, user_id=sponsor_user_id,
            type=NotificationType.sponsor_refunded,
            title="Sponsorship Refunded",
            message=f"Your sponsorship payment of ${payment.amount_cents / 100:.2f} has been refunded by the organizer.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id, "payment_id": payment.id},
        )

    from app.models.event import Event
    event_obj = (await db.execute(
        sa_select(Event).where(Event.id == event_id)
    )).scalar_one_or_none()
    if event_obj:
        await notif_svc.create_notification(
            db, user_id=event_obj.organizer_id,
            type=NotificationType.sponsor_refunded,
            title="Sponsorship Refund Processed",
            message=f"Refund of ${payment.amount_cents / 100:.2f} has been processed for bid #{bid_id}.",
            data={"event_id": event_id, "category_id": cat_id, "bid_id": bid_id, "payment_id": payment.id},
        )

    await db.commit()
    await db.refresh(payment)
    return payment


# ── Sponsor Bid Events ──

@router.get(
    "/me/sponsor-bid-events",
    dependencies=[Depends(_feature_guard)],
)
async def list_sponsor_bid_events(db: DbSession, current_user: CurrentUser):
    """Events the sponsor has placed bids on, with bid summary counts."""
    from datetime import datetime, timezone
    from app.api.v1.events import _event_to_response, _get_first_images
    from app.services import funding as funding_service
    events = await sponsor_svc.get_sponsor_bid_events(db, current_user.id)
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    first_images = await _get_first_images(db, event_ids) if event_ids else {}
    now = datetime.now(timezone.utc)
    result = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        resp = _event_to_response(
            e,
            total_pledged_cents=total_cents,
            funding_days_left=days_left,
            first_image_url=first_images.get(e.id),
        )
        summary = await sponsor_svc.get_sponsor_bid_summary_for_event(db, e.id, current_user.id)
        result.append({
            **resp.model_dump(mode="json"),
            "bid_summary": summary,
        })
    return result


# ── Sponsorship-Available Events ──

@router.get(
    "/events/sponsorship-available",
    dependencies=[Depends(_feature_guard)],
)
async def list_sponsorship_available_events(
    db: DbSession,
    current_user: CurrentUser,
    exclude_my_bids: bool = Query(False),
):
    """Events with at least one sponsorship category that has open spots."""
    from datetime import datetime, timezone
    from app.api.v1.events import _event_to_response, _get_first_images
    from app.services import funding as funding_service

    items = await sponsor_svc.get_events_with_sponsorship_available(
        db,
        sponsor_user_id=current_user.id,
        exclude_my_bids=exclude_my_bids,
    )
    if not items:
        return []

    event_ids = [it["event"].id for it in items]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids)
    first_images = await _get_first_images(db, event_ids)
    now = datetime.now(timezone.utc)

    result = []
    for it in items:
        e = it["event"]
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        resp = _event_to_response(
            e,
            total_pledged_cents=total_cents,
            funding_days_left=days_left,
            first_image_url=first_images.get(e.id),
        )
        result.append({
            **resp.model_dump(mode="json"),
            "categories_summary": it["categories_summary"],
        })
    return result


# ── Organizer: My Sponsors ──

@router.get(
    "/me/organizer-sponsors",
    dependencies=[Depends(_feature_guard)],
)
async def list_organizer_sponsors(
    db: DbSession,
    current_user: CurrentUser,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """Sponsors with active bids on organizer's events."""
    if current_user.role not in (UserRole.organizer, UserRole.admin):
        raise HTTPException(status_code=403, detail="Only organizers can view their sponsors")
    return await sponsor_svc.get_organizer_sponsors(db, current_user.id, offset=offset, limit=limit)


@router.get(
    "/me/organizer-sponsors/{sponsor_user_id}/events",
    dependencies=[Depends(_feature_guard)],
)
async def list_sponsor_events_for_organizer(
    sponsor_user_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Events where a specific sponsor has bids, for this organizer."""
    if current_user.role not in (UserRole.organizer, UserRole.admin):
        raise HTTPException(status_code=403, detail="Only organizers can view their sponsors")
    return await sponsor_svc.get_sponsor_events_for_organizer(db, current_user.id, sponsor_user_id)


# ── Sponsor Tickets ──

@router.get(
    "/me/sponsor-tickets",
    response_model=list[SponsorTicketResponse],
    dependencies=[Depends(_feature_guard)],
)
async def list_my_sponsor_tickets(db: DbSession, current_user: CurrentUser):
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


@router.post(
    "/events/{event_id}/scan-sponsor",
    dependencies=[Depends(_feature_guard)],
)
async def scan_sponsor_ticket(
    event_id: int,
    body: dict,
    db: DbSession,
    current_user: CurrentUser,
):
    payload = body.get("encrypted_payload", "")
    if not payload:
        raise HTTPException(status_code=400, detail="encrypted_payload required")
    result = await sponsor_svc.scan_sponsor_ticket(db, event_id, payload)
    await db.commit()
    return result


# ── Category Prerequisites (Organizer creates) ──

@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/prerequisites",
    status_code=201,
    dependencies=[Depends(_feature_guard)],
)
async def create_prerequisite(
    event_id: int,
    cat_id: int,
    name: str = Form(...),
    description: str | None = Form(None),
    is_required: bool = Form(True),
    requires_document: bool = Form(False),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    """Organizer adds a prerequisite to a sponsorship category."""
    from app.models.prerequisite import CategoryPrerequisite
    cat = await sponsor_svc._get_category(db, cat_id)
    await sponsor_svc._require_organizer(db, cat.event_id, current_user)
    prereq = CategoryPrerequisite(
        category_id=cat_id, name=name, description=description,
        is_required=is_required, requires_document=requires_document,
    )
    db.add(prereq)
    await db.flush()
    await db.refresh(prereq)
    return {"id": prereq.id, "name": prereq.name, "description": prereq.description, "is_required": prereq.is_required, "requires_document": prereq.requires_document}


@router.get(
    "/events/{event_id}/sponsorships/{cat_id}/prerequisites",
    dependencies=[Depends(_feature_guard)],
)
async def list_prerequisites(
    event_id: int,
    cat_id: int,
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    """List prerequisites for a category."""
    from sqlalchemy import select
    from app.models.prerequisite import CategoryPrerequisite
    q = select(CategoryPrerequisite).where(CategoryPrerequisite.category_id == cat_id)
    items = (await db.execute(q)).scalars().all()
    return [{"id": p.id, "name": p.name, "description": p.description, "is_required": p.is_required, "requires_document": p.requires_document} for p in items]


@router.delete(
    "/events/{event_id}/sponsorships/{cat_id}/prerequisites/{prereq_id}",
    status_code=204,
    dependencies=[Depends(_feature_guard)],
)
async def delete_prerequisite(
    event_id: int,
    cat_id: int,
    prereq_id: int,
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    """Organizer deletes a prerequisite."""
    from sqlalchemy import select
    from app.models.prerequisite import CategoryPrerequisite
    cat = await sponsor_svc._get_category(db, cat_id)
    await sponsor_svc._require_organizer(db, cat.event_id, current_user)
    prereq = (await db.execute(
        select(CategoryPrerequisite).where(CategoryPrerequisite.id == prereq_id)
    )).scalar_one_or_none()
    if not prereq:
        raise HTTPException(status_code=404, detail="Prerequisite not found")
    await db.delete(prereq)
    await db.flush()


# ── Bid Prerequisite Uploads (Sponsor uploads) ──

@router.post(
    "/bids/{bid_id}/prerequisites/{prereq_id}/upload",
    dependencies=[Depends(_feature_guard)],
)
async def upload_prerequisite_document(
    bid_id: int,
    prereq_id: int,
    file: UploadFile = File(...),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    """Sponsor uploads a document for a prerequisite."""
    from sqlalchemy import select
    from app.models.prerequisite import BidPrerequisiteUpload
    from app.models.sponsor import SponsorBid
    bid = (await db.execute(select(SponsorBid).where(SponsorBid.id == bid_id))).scalar_one_or_none()
    if not bid or bid.sponsor_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your bid")

    import os, uuid
    upload_dir = "static/uploads/prerequisites"
    os.makedirs(upload_dir, exist_ok=True)
    ext = os.path.splitext(file.filename)[1] if file.filename else ".pdf"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(upload_dir, filename)
    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)

    upload = BidPrerequisiteUpload(
        bid_id=bid_id,
        prerequisite_id=prereq_id,
        file_url=f"/static/uploads/prerequisites/{filename}",
    )
    db.add(upload)
    await db.flush()
    await db.refresh(upload)
    return {"id": upload.id, "file_url": upload.file_url, "status": upload.status.value}


@router.post(
    "/events/{event_id}/sponsorships/{cat_id}/upload-prerequisite/{prereq_id}",
    dependencies=[Depends(_feature_guard)],
)
async def upload_category_prerequisite(
    event_id: int,
    cat_id: int,
    prereq_id: int,
    file: UploadFile = File(...),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    """Sponsor uploads a document for a category prerequisite, linked to their latest active bid."""
    from sqlalchemy import select
    from app.models.prerequisite import CategoryPrerequisite, BidPrerequisiteUpload
    from app.models.sponsor import SponsorBid, BidStatus

    prereq = (await db.execute(
        select(CategoryPrerequisite).where(
            CategoryPrerequisite.id == prereq_id,
            CategoryPrerequisite.category_id == cat_id,
        )
    )).scalar_one_or_none()
    if not prereq:
        raise HTTPException(status_code=404, detail="Prerequisite not found")

    bid = (await db.execute(
        select(SponsorBid)
        .where(
            SponsorBid.category_id == cat_id,
            SponsorBid.sponsor_user_id == current_user.id,
            SponsorBid.status.notin_([BidStatus.rejected]),
        )
        .order_by(SponsorBid.created_at.desc())
    )).scalars().first()
    if not bid:
        raise HTTPException(status_code=400, detail="You have no active bid for this category")

    existing = (await db.execute(
        select(BidPrerequisiteUpload).where(
            BidPrerequisiteUpload.bid_id == bid.id,
            BidPrerequisiteUpload.prerequisite_id == prereq_id,
        )
    )).scalar_one_or_none()
    if existing:
        await db.delete(existing)
        await db.flush()

    import os, uuid
    upload_dir = "static/uploads/prerequisites"
    os.makedirs(upload_dir, exist_ok=True)
    ext = os.path.splitext(file.filename)[1] if file.filename else ".pdf"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(upload_dir, filename)
    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)

    upload = BidPrerequisiteUpload(
        bid_id=bid.id,
        prerequisite_id=prereq_id,
        file_url=f"/static/uploads/prerequisites/{filename}",
    )
    db.add(upload)
    await db.flush()
    await db.refresh(upload)
    return {"id": upload.id, "file_url": upload.file_url, "status": upload.status.value}


@router.get(
    "/bids/{bid_id}/prerequisites",
    dependencies=[Depends(_feature_guard)],
)
async def list_bid_prerequisite_uploads(
    bid_id: int,
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    """List all prerequisite uploads for a bid."""
    from sqlalchemy import select
    from app.models.prerequisite import BidPrerequisiteUpload
    q = select(BidPrerequisiteUpload).where(BidPrerequisiteUpload.bid_id == bid_id)
    items = (await db.execute(q)).scalars().all()
    return [
        {
            "id": u.id,
            "bid_id": u.bid_id,
            "prerequisite_id": u.prerequisite_id,
            "file_url": u.file_url,
            "status": u.status.value,
            "reviewed_at": u.reviewed_at.isoformat() if u.reviewed_at else None,
            "reviewer_note": u.reviewer_note,
        }
        for u in items
    ]


# ── Review Uploads (Organizer) ──

@router.patch(
    "/bids/{bid_id}/prerequisites/{prereq_id}/review",
    dependencies=[Depends(_feature_guard)],
)
async def review_prerequisite_upload(
    bid_id: int,
    prereq_id: int,
    status: str = Form(...),
    reviewer_note: str | None = Form(None),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    """Organizer approves or rejects an uploaded prerequisite document."""
    from sqlalchemy import select
    from app.models.prerequisite import BidPrerequisiteUpload, UploadStatus
    from app.models.sponsor import SponsorBid
    from datetime import datetime, timezone
    bid = (await db.execute(select(SponsorBid).where(SponsorBid.id == bid_id))).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")
    cat = await sponsor_svc._get_category(db, bid.category_id)
    await sponsor_svc._require_organizer(db, cat.event_id, current_user)

    upload = (await db.execute(
        select(BidPrerequisiteUpload).where(
            BidPrerequisiteUpload.bid_id == bid_id,
            BidPrerequisiteUpload.prerequisite_id == prereq_id,
        )
    )).scalar_one_or_none()
    if not upload:
        raise HTTPException(status_code=404, detail="Upload not found")

    upload.status = UploadStatus(status)
    upload.reviewed_at = datetime.now(timezone.utc)
    upload.reviewer_note = reviewer_note
    await db.flush()
    await db.refresh(upload)

    return {"id": upload.id, "status": upload.status.value, "reviewer_note": upload.reviewer_note}


# ── Public Sponsor Carousel ──

@router.get(
    "/events/{event_id}/sponsors",
    dependencies=[Depends(_feature_guard)],
)
async def list_event_sponsors(event_id: int, db: DbSession):
    """Public endpoint: returns approved sponsor logos for the carousel."""
    sponsors = await sponsor_svc.get_paid_sponsors(db, event_id)
    return sponsors
