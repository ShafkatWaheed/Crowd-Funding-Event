"""
Sponsor marketplace service: profiles, categories, bids, payments, tickets.
"""
from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.event import Event
from app.models.sponsor import (
    SponsorProfile, SponsorshipCategory, SponsorBid, BidStatus,
    SponsorPayment, PaymentStatus, SponsorTicket,
)
from app.schemas.sponsor import (
    SponsorProfileCreate, SponsorProfileUpdate,
    CategoryCreate, CategoryUpdate,
    BidCreate, BidUpdate,
)


# ── Sponsor Profile ──

async def get_profile(db: AsyncSession, user_id: int) -> SponsorProfile | None:
    q = select(SponsorProfile).where(SponsorProfile.user_id == user_id)
    return (await db.execute(q)).scalar_one_or_none()


async def create_profile(
    db: AsyncSession, user: User, data: SponsorProfileCreate
) -> SponsorProfile:
    existing = await get_profile(db, user.id)
    if existing:
        raise HTTPException(status_code=409, detail="Sponsor profile already exists")

    profile = SponsorProfile(
        user_id=user.id,
        company_name=data.company_name,
        contact_name=data.contact_name,
        profession=data.profession,
        logo_url=data.logo_url,
        description=data.description,
        website_url=data.website_url,
    )
    db.add(profile)

    if user.role == UserRole.customer:
        user.role = UserRole.sponsor
        db.add(user)

    await db.flush()
    await db.refresh(profile)
    return profile


async def update_profile(
    db: AsyncSession, user_id: int, data: SponsorProfileUpdate
) -> SponsorProfile:
    profile = await get_profile(db, user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Sponsor profile not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(profile, field, value)

    await db.flush()
    await db.refresh(profile)
    return profile


# ── Sponsorship Categories ──

async def _require_organizer(db: AsyncSession, event_id: int, user: User) -> Event:
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Only the organizer can manage sponsorship categories")
    return event


async def list_categories(db: AsyncSession, event_id: int) -> list[SponsorshipCategory]:
    q = (
        select(SponsorshipCategory)
        .where(SponsorshipCategory.event_id == event_id)
        .order_by(SponsorshipCategory.sort_order, SponsorshipCategory.id)
    )
    return list((await db.execute(q)).scalars().all())


async def get_prereq_counts(db: AsyncSession, category_ids: list[int]) -> dict[int, int]:
    """Return {category_id: prerequisite_count} for the given IDs."""
    if not category_ids:
        return {}
    from app.models.prerequisite import CategoryPrerequisite
    q = (
        select(CategoryPrerequisite.category_id, func.count(CategoryPrerequisite.id))
        .where(CategoryPrerequisite.category_id.in_(category_ids))
        .group_by(CategoryPrerequisite.category_id)
    )
    rows = (await db.execute(q)).all()
    return {cat_id: cnt for cat_id, cnt in rows}


async def create_category(
    db: AsyncSession, event_id: int, user: User, data: CategoryCreate
) -> SponsorshipCategory:
    await _require_organizer(db, event_id, user)
    cat = SponsorshipCategory(
        event_id=event_id,
        name=data.name,
        description=data.description,
        image_url=data.image_url,
        total_spots=data.total_spots,
        min_bid_cents=data.min_bid_cents,
        sort_order=data.sort_order,
    )
    db.add(cat)
    await db.flush()
    await db.refresh(cat)
    return cat


async def update_category(
    db: AsyncSession, cat_id: int, user: User, data: CategoryUpdate
) -> SponsorshipCategory:
    cat = (await db.execute(
        select(SponsorshipCategory).where(SponsorshipCategory.id == cat_id)
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await _require_organizer(db, cat.event_id, user)

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(cat, field, value)
    await db.flush()
    await db.refresh(cat)
    return cat


async def delete_category(db: AsyncSession, cat_id: int, user: User) -> None:
    cat = (await db.execute(
        select(SponsorshipCategory).where(SponsorshipCategory.id == cat_id)
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await _require_organizer(db, cat.event_id, user)
    await db.delete(cat)
    await db.flush()


# ── Template CRUD ──

async def list_templates(db: AsyncSession, user: User) -> list[SponsorshipCategory]:
    q = (
        select(SponsorshipCategory)
        .where(SponsorshipCategory.is_template == True, SponsorshipCategory.organizer_id == user.id)
        .order_by(SponsorshipCategory.name)
    )
    return list((await db.execute(q)).scalars().all())


async def create_template(db: AsyncSession, user: User, data: CategoryCreate) -> SponsorshipCategory:
    cat = SponsorshipCategory(
        event_id=None,
        organizer_id=user.id,
        is_template=True,
        name=data.name,
        description=data.description,
        image_url=data.image_url,
        total_spots=data.total_spots,
        min_bid_cents=data.min_bid_cents,
        sort_order=data.sort_order,
    )
    db.add(cat)
    await db.flush()
    await db.refresh(cat)
    return cat


async def update_template(db: AsyncSession, template_id: int, user: User, data: CategoryUpdate) -> SponsorshipCategory:
    cat = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(cat, field, value)
    await db.flush()
    await db.refresh(cat)
    return cat


async def delete_template(db: AsyncSession, template_id: int, user: User) -> None:
    cat = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")
    await db.delete(cat)
    await db.flush()


async def copy_template_to_event(
    db: AsyncSession, template_id: int, event_id: int, user: User
) -> SponsorshipCategory:
    """Copy a template category (and its prerequisites) into an event-scoped category."""
    template = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    await _require_organizer(db, event_id, user)

    cat = SponsorshipCategory(
        event_id=event_id,
        organizer_id=user.id,
        is_template=False,
        name=template.name,
        description=template.description,
        image_url=template.image_url,
        total_spots=template.total_spots,
        min_bid_cents=template.min_bid_cents,
        sort_order=template.sort_order,
    )
    db.add(cat)
    await db.flush()
    await db.refresh(cat)

    from app.models.prerequisite import CategoryPrerequisite
    prereqs = (await db.execute(
        select(CategoryPrerequisite).where(CategoryPrerequisite.category_id == template_id)
    )).scalars().all()

    for p in prereqs:
        new_prereq = CategoryPrerequisite(
            category_id=cat.id,
            name=p.name,
            description=p.description,
            is_required=p.is_required,
        )
        db.add(new_prereq)

    await db.flush()
    await db.refresh(cat)
    return cat


async def get_bid_stats(db: AsyncSession, cat_id: int) -> tuple[int, list[int]]:
    """Return (bid_count, list_of_amounts) for anonymous bid stats."""
    q = select(SponsorBid).where(
        SponsorBid.category_id == cat_id,
        SponsorBid.status.in_([BidStatus.pending, BidStatus.accepted, BidStatus.paid]),
    )
    bids = list((await db.execute(q)).scalars().all())
    return len(bids), [b.amount_cents for b in bids]


async def get_my_bid_count(db: AsyncSession, cat_id: int, user_id: int) -> int:
    """Count active bids the sponsor has on this category."""
    active_statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
    q = select(SponsorBid).where(
        SponsorBid.category_id == cat_id,
        SponsorBid.sponsor_user_id == user_id,
        SponsorBid.status.in_(active_statuses),
    )
    bids = list((await db.execute(q)).scalars().all())
    return len(bids)


async def get_my_bids(db: AsyncSession, cat_id: int, user_id: int) -> list[dict]:
    """Return the sponsor's own bids for a category (all statuses except withdrawn)."""
    q = select(SponsorBid).where(
        SponsorBid.category_id == cat_id,
        SponsorBid.sponsor_user_id == user_id,
        SponsorBid.status != BidStatus.withdrawn,
    ).order_by(SponsorBid.id.desc())
    bids = list((await db.execute(q)).scalars().all())
    return [
        {"id": b.id, "amount_cents": b.amount_cents, "status": b.status.value}
        for b in bids
    ]


# ── Bids ──

async def _get_category(db: AsyncSession, cat_id: int) -> SponsorshipCategory:
    cat = (await db.execute(
        select(SponsorshipCategory).where(SponsorshipCategory.id == cat_id)
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    return cat


async def place_bid(
    db: AsyncSession, cat_id: int, user: User, data: BidCreate
) -> SponsorBid:
    if user.role != UserRole.sponsor:
        raise HTTPException(status_code=403, detail="Only sponsors can place bids")

    cat = await _get_category(db, cat_id)

    if data.amount_cents < cat.min_bid_cents:
        raise HTTPException(
            status_code=400,
            detail=f"Bid must be at least {cat.min_bid_cents} cents (${cat.min_bid_cents / 100:.2f})",
        )
    if cat.filled_spots >= cat.total_spots:
        raise HTTPException(status_code=400, detail="No spots available in this category")

    active_statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
    my_active_bids = (await db.execute(
        select(SponsorBid).where(
            SponsorBid.category_id == cat_id,
            SponsorBid.sponsor_user_id == user.id,
            SponsorBid.status.in_(active_statuses),
        )
    )).scalars().all()

    if len(list(my_active_bids)) >= cat.total_spots:
        raise HTTPException(
            status_code=409,
            detail=f"You already have {len(list(my_active_bids))} active bid(s) — max is {cat.total_spots} (total spots)",
        )

    bid = SponsorBid(
        category_id=cat_id,
        sponsor_user_id=user.id,
        amount_cents=data.amount_cents,
        proposal_text=data.proposal_text,
    )
    db.add(bid)
    await db.flush()
    await db.refresh(bid)
    return bid


async def update_bid(
    db: AsyncSession, bid_id: int, user: User, data: BidUpdate
) -> SponsorBid:
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")
    if bid.sponsor_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your bid")
    if bid.status != BidStatus.pending:
        raise HTTPException(status_code=400, detail="Can only update pending bids")

    if data.amount_cents is not None:
        cat = await _get_category(db, bid.category_id)
        if data.amount_cents < cat.min_bid_cents:
            raise HTTPException(status_code=400, detail=f"Bid must be at least {cat.min_bid_cents} cents")
        bid.amount_cents = data.amount_cents
    if data.proposal_text is not None:
        bid.proposal_text = data.proposal_text

    await db.flush()
    await db.refresh(bid)
    return bid


async def withdraw_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorBid:
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")
    if bid.sponsor_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your bid")
    if bid.status != BidStatus.pending:
        raise HTTPException(status_code=400, detail="Can only withdraw pending bids")

    bid.status = BidStatus.withdrawn
    await db.flush()
    await db.refresh(bid)
    return bid


async def list_bids(
    db: AsyncSession, cat_id: int, user: User
) -> list[SponsorBid]:
    """Organizer-only: list all bids for a category."""
    cat = await _get_category(db, cat_id)
    await _require_organizer(db, cat.event_id, user)
    q = (
        select(SponsorBid)
        .where(SponsorBid.category_id == cat_id)
        .order_by(SponsorBid.amount_cents.desc())
    )
    return list((await db.execute(q)).scalars().all())


async def accept_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorBid:
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")

    cat = await _get_category(db, bid.category_id)
    await _require_organizer(db, cat.event_id, user)

    if bid.status != BidStatus.pending:
        raise HTTPException(status_code=400, detail="Can only accept pending bids")
    if cat.filled_spots >= cat.total_spots:
        raise HTTPException(status_code=400, detail="No spots available — category is full")

    from app.models.prerequisite import CategoryPrerequisite, BidPrerequisiteUpload, UploadStatus
    from datetime import datetime, timezone
    required_prereqs = (await db.execute(
        select(CategoryPrerequisite).where(
            CategoryPrerequisite.category_id == bid.category_id,
            CategoryPrerequisite.is_required == True,
        )
    )).scalars().all()

    for prereq in required_prereqs:
        upload = (await db.execute(
            select(BidPrerequisiteUpload).where(
                BidPrerequisiteUpload.bid_id == bid.id,
                BidPrerequisiteUpload.prerequisite_id == prereq.id,
            )
        )).scalar_one_or_none()
        if upload and upload.status == UploadStatus.pending:
            upload.status = UploadStatus.approved
            upload.reviewed_at = datetime.now(timezone.utc)

    bid.status = BidStatus.accepted
    cat.filled_spots += 1
    await db.flush()
    await db.refresh(bid)

    await _ensure_sponsor_ticket(db, cat.event_id, bid.sponsor_user_id)

    return bid


async def reject_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorBid:
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")

    cat = await _get_category(db, bid.category_id)
    await _require_organizer(db, cat.event_id, user)

    if bid.status != BidStatus.pending:
        raise HTTPException(status_code=400, detail="Can only reject pending bids")

    bid.status = BidStatus.rejected
    await db.flush()
    await db.refresh(bid)
    return bid


# ── Payments ──

async def pay_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorPayment:
    """Sponsor pays for an accepted bid. Creates payment + auto-generates sponsor ticket."""
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")
    if bid.sponsor_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your bid")
    if bid.status != BidStatus.accepted:
        raise HTTPException(status_code=400, detail="Can only pay for accepted bids")

    existing_payment = (await db.execute(
        select(SponsorPayment).where(SponsorPayment.bid_id == bid_id)
    )).scalar_one_or_none()
    if existing_payment:
        raise HTTPException(status_code=409, detail="Bid already paid")

    from app.services import platform_settings as settings_svc
    commission_pct = await settings_svc.get_int(db, "sponsor_commission_percent")
    platform_cut = (bid.amount_cents * commission_pct) // 100
    net = bid.amount_cents - platform_cut

    from datetime import datetime
    now = datetime.utcnow()
    receipt = f"SP-{now.strftime('%Y%m%d')}-{bid.category_id}-{bid_id}"

    payment = SponsorPayment(
        bid_id=bid_id,
        amount_cents=bid.amount_cents,
        platform_cut_cents=platform_cut,
        net_to_organizer_cents=net,
        receipt_number=receipt,
    )
    db.add(payment)

    bid.status = BidStatus.paid
    await db.flush()
    await db.refresh(payment)

    cat = await _get_category(db, bid.category_id)
    await _ensure_sponsor_ticket(db, cat.event_id, user.id)

    return payment


async def _ensure_sponsor_ticket(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> SponsorTicket:
    """Create or update sponsor ticket with QR data."""
    existing = (await db.execute(
        select(SponsorTicket).where(
            SponsorTicket.event_id == event_id,
            SponsorTicket.sponsor_user_id == sponsor_user_id,
        )
    )).scalar_one_or_none()

    from app.services.ticket_crypto import encrypt_ticket_qr
    import secrets
    ticket_code = secrets.token_hex(16)

    if existing:
        existing.qr_data_encrypted = encrypt_ticket_qr(
            ticket_code, event_id, existing.id
        )
        await db.flush()
        await db.refresh(existing)
        return existing

    from datetime import datetime
    now = datetime.utcnow()
    ticket = SponsorTicket(
        event_id=event_id,
        sponsor_user_id=sponsor_user_id,
        receipt_number=f"SPT-{now.strftime('%Y%m%d')}-{event_id}-0",
    )
    db.add(ticket)
    await db.flush()
    await db.refresh(ticket)

    ticket.receipt_number = f"SPT-{now.strftime('%Y%m%d')}-{event_id}-{ticket.id}"
    ticket.qr_data_encrypted = encrypt_ticket_qr(
        ticket_code, event_id, ticket.id
    )
    await db.flush()
    await db.refresh(ticket)
    return ticket


# ── Refund individual bid (organizer action) ──

async def refund_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorPayment:
    """Organizer refunds a paid bid. Reverses payment, bid, filled_spots, and ticket if needed."""
    bid = (await db.execute(
        select(SponsorBid).where(SponsorBid.id == bid_id)
    )).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")

    cat = await _get_category(db, bid.category_id)
    await _require_organizer(db, cat.event_id, user)

    if bid.status != BidStatus.paid:
        raise HTTPException(status_code=400, detail="Can only refund paid bids")

    payment = (await db.execute(
        select(SponsorPayment).where(SponsorPayment.bid_id == bid_id)
    )).scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.status != PaymentStatus.completed:
        raise HTTPException(status_code=400, detail="Payment already refunded")

    # Transition through refund_processing then immediately to refunded.
    # When a payment gateway is added, stop at refund_processing and enqueue ARQ.
    payment.status = PaymentStatus.refund_processing
    bid.status = BidStatus.rejected
    if cat.filled_spots > 0:
        cat.filled_spots -= 1

    other_active = (await db.execute(
        select(func.count()).select_from(SponsorBid).where(
            SponsorBid.sponsor_user_id == bid.sponsor_user_id,
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid]),
            SponsorBid.id != bid.id,
            SponsorBid.category_id.in_(
                select(SponsorshipCategory.id).where(SponsorshipCategory.event_id == cat.event_id)
            ),
        )
    )).scalar_one()

    refunded_with_payment = (await db.execute(
        select(func.count()).select_from(SponsorBid)
        .join(SponsorPayment, SponsorPayment.bid_id == SponsorBid.id)
        .where(
            SponsorBid.sponsor_user_id == bid.sponsor_user_id,
            SponsorPayment.status.in_([PaymentStatus.refunded, PaymentStatus.refund_processing]),
            SponsorBid.category_id.in_(
                select(SponsorshipCategory.id).where(SponsorshipCategory.event_id == cat.event_id)
            ),
        )
    )).scalar_one()

    if other_active == 0 and refunded_with_payment == 0:
        from sqlalchemy import delete as sa_delete
        await db.execute(
            sa_delete(SponsorTicket).where(
                SponsorTicket.event_id == cat.event_id,
                SponsorTicket.sponsor_user_id == bid.sponsor_user_id,
            )
        )

    payment.status = PaymentStatus.refunded
    await db.flush()
    await db.refresh(payment)
    return payment


# ── Refund all sponsor payments for event (on cancellation) ──

async def refund_all_sponsor_payments_for_event(db: AsyncSession, event_id: int) -> int:
    """
    Mark all completed sponsor payments as refund_processing,
    reset bids, decrement filled_spots, delete sponsor tickets,
    and enqueue bulk ARQ job. Returns the number of payments queued.
    """
    cats = await list_categories(db, event_id)
    cat_ids = [c.id for c in cats]
    if not cat_ids:
        return 0

    paid_bids_q = select(SponsorBid).where(
        SponsorBid.category_id.in_(cat_ids),
        SponsorBid.status == BidStatus.paid,
    )
    paid_bids = list((await db.execute(paid_bids_q)).scalars().all())

    refunded_count = 0
    for bid in paid_bids:
        payment = (await db.execute(
            select(SponsorPayment).where(SponsorPayment.bid_id == bid.id)
        )).scalar_one_or_none()
        if payment and payment.status == PaymentStatus.completed:
            payment.status = PaymentStatus.refund_processing
            refunded_count += 1
            payment.status = PaymentStatus.refunded

        cat = next((c for c in cats if c.id == bid.category_id), None)
        if cat and cat.filled_spots > 0:
            cat.filled_spots -= 1

        bid.status = BidStatus.rejected

    accepted_bids_q = select(SponsorBid).where(
        SponsorBid.category_id.in_(cat_ids),
        SponsorBid.status == BidStatus.accepted,
    )
    accepted_bids = list((await db.execute(accepted_bids_q)).scalars().all())
    for bid in accepted_bids:
        cat = next((c for c in cats if c.id == bid.category_id), None)
        if cat and cat.filled_spots > 0:
            cat.filled_spots -= 1
        bid.status = BidStatus.rejected

    from sqlalchemy import delete as sa_delete
    await db.execute(
        sa_delete(SponsorTicket).where(SponsorTicket.event_id == event_id)
    )

    await db.flush()
    return refunded_count


# ── Sponsor Bid Events ──

async def get_sponsor_bid_events(db: AsyncSession, sponsor_user_id: int) -> list[Event]:
    """Return distinct events where this sponsor has placed at least one active bid."""
    from sqlalchemy import distinct
    from sqlalchemy.orm import selectinload
    active_statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
    event_ids_q = (
        select(distinct(SponsorshipCategory.event_id))
        .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorBid.sponsor_user_id == sponsor_user_id,
            SponsorBid.status.in_(active_statuses),
        )
    )
    q = (
        select(Event)
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .where(Event.id.in_(event_ids_q))
        .order_by(Event.created_at.desc())
    )
    return list((await db.execute(q)).scalars().all())


async def get_sponsor_bid_summary_for_event(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> dict:
    """Return bid counts by status for a sponsor on a given event."""
    q = (
        select(SponsorBid.status, SponsorBid.id)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorBid.sponsor_user_id == sponsor_user_id,
        )
    )
    rows = (await db.execute(q)).all()
    counts = {"pending": 0, "accepted": 0, "rejected": 0, "paid": 0, "withdrawn": 0}
    for row in rows:
        status_val = row[0].value if hasattr(row[0], 'value') else str(row[0])
        if status_val in counts:
            counts[status_val] += 1
    return counts


async def get_events_with_sponsorship_available(
    db: AsyncSession,
    sponsor_user_id: int | None = None,
    exclude_my_bids: bool = False,
) -> list[dict]:
    """Return events that have at least one sponsorship category with open spots.

    Each result dict contains the Event ORM object and a list of category
    summaries (name, total_spots, filled_spots, min_bid_cents).
    Excludes cancelled/completed events and template categories.
    """
    from sqlalchemy import distinct
    from sqlalchemy.orm import selectinload

    excluded_statuses = [
        Event.status.in_(["cancelled", "completed"]),
    ]

    open_cat_q = (
        select(distinct(SponsorshipCategory.event_id))
        .where(
            SponsorshipCategory.event_id.isnot(None),
            SponsorshipCategory.is_template == False,
            SponsorshipCategory.filled_spots < SponsorshipCategory.total_spots,
        )
    )

    if exclude_my_bids and sponsor_user_id:
        already_bid_event_ids = (
            select(distinct(SponsorshipCategory.event_id))
            .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorBid.sponsor_user_id == sponsor_user_id,
                SponsorBid.status.in_([BidStatus.pending, BidStatus.accepted, BidStatus.paid]),
            )
        )
        open_cat_q = open_cat_q.where(
            SponsorshipCategory.event_id.notin_(already_bid_event_ids)
        )

    q = (
        select(Event)
        .options(
            selectinload(Event.venue),
            selectinload(Event.ticket_strategy),
            selectinload(Event.sponsorship_categories),
        )
        .where(
            Event.id.in_(open_cat_q),
            Event.status.notin_(["cancelled", "completed"]),
        )
        .order_by(Event.created_at.desc())
    )
    events = list((await db.execute(q)).scalars().all())

    results = []
    for e in events:
        cats = [
            {
                "name": c.name,
                "total_spots": c.total_spots,
                "filled_spots": c.filled_spots,
                "available_spots": c.total_spots - c.filled_spots,
                "min_bid_cents": c.min_bid_cents,
            }
            for c in (e.sponsorship_categories or [])
            if not c.is_template and c.filled_spots < c.total_spots
        ]
        results.append({"event": e, "categories_summary": cats})
    return results


# ── Sponsor Tickets ──

async def get_sponsor_ticket(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> SponsorTicket | None:
    return (await db.execute(
        select(SponsorTicket).where(
            SponsorTicket.event_id == event_id,
            SponsorTicket.sponsor_user_id == sponsor_user_id,
        )
    )).scalar_one_or_none()


async def list_sponsor_tickets(
    db: AsyncSession, sponsor_user_id: int
) -> list[SponsorTicket]:
    from sqlalchemy.orm import selectinload
    q = (
        select(SponsorTicket)
        .where(SponsorTicket.sponsor_user_id == sponsor_user_id)
        .options(selectinload(SponsorTicket.event).selectinload(Event.venue))
        .order_by(SponsorTicket.created_at.desc())
    )
    return list((await db.execute(q)).scalars().all())


async def get_won_categories(
    db: AsyncSession, event_id: int, sponsor_user_id: int
) -> list[dict]:
    """Return category info where sponsor has accepted, paid, or refunded bids."""
    from app.models.prerequisite import CategoryPrerequisite, BidPrerequisiteUpload
    q = (
        select(
            SponsorshipCategory.id,
            SponsorshipCategory.name,
            SponsorBid.id.label("bid_id"),
            SponsorBid.amount_cents,
            SponsorBid.status,
        )
        .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorBid.sponsor_user_id == sponsor_user_id,
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid, BidStatus.rejected]),
        )
    )
    rows = (await db.execute(q)).all()

    # Filter rejected bids to only those that have a refunded payment
    filtered = []
    for r in rows:
        if r.status == BidStatus.rejected:
            payment = (await db.execute(
                select(SponsorPayment).where(SponsorPayment.bid_id == r.bid_id)
            )).scalar_one_or_none()
            if not payment or payment.status != PaymentStatus.refunded:
                continue
        filtered.append(r)

    results = []
    for r in filtered:
        prereqs_q = select(CategoryPrerequisite).where(
            CategoryPrerequisite.category_id == r.id,
        )
        prereqs = (await db.execute(prereqs_q)).scalars().all()
        prereq_list = []
        for p in prereqs:
            upload = (await db.execute(
                select(BidPrerequisiteUpload).where(
                    BidPrerequisiteUpload.bid_id == r.bid_id,
                    BidPrerequisiteUpload.prerequisite_id == p.id,
                )
            )).scalar_one_or_none()
            prereq_list.append({
                "id": p.id,
                "name": p.name,
                "is_required": p.is_required,
                "requires_document": p.requires_document,
                "upload_status": upload.status.value if upload else None,
            })

        payment = (await db.execute(
            select(SponsorPayment).where(SponsorPayment.bid_id == r.bid_id)
        )).scalar_one_or_none()

        cat_status = r.status.value
        if r.status == BidStatus.rejected and payment and payment.status == PaymentStatus.refunded:
            cat_status = "refunded"

        results.append({
            "name": r.name,
            "amount_cents": r.amount_cents,
            "status": cat_status,
            "prerequisites": prereq_list,
            "payment_receipt_number": payment.receipt_number if payment else None,
            "payment_status": payment.status.value if payment else None,
            "payment_created_at": payment.created_at.isoformat() if payment and payment.created_at else None,
        })
    return results


async def scan_sponsor_ticket(
    db: AsyncSession, event_id: int, encrypted_payload: str
) -> dict:
    """Decrypt QR and return sponsor info + won categories."""
    from app.services.ticket_crypto import decrypt_ticket_qr
    try:
        data = decrypt_ticket_qr(encrypted_payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    ticket_event_id = data.get("eid")
    ticket_id = data.get("sid")
    if ticket_event_id != event_id:
        raise HTTPException(status_code=400, detail="QR does not belong to this event")

    ticket = (await db.execute(
        select(SponsorTicket).where(SponsorTicket.id == ticket_id)
    )).scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Sponsor ticket not found")

    from datetime import datetime
    already_scanned = ticket.scanned_at is not None
    if not ticket.scanned_at:
        ticket.scanned_at = datetime.utcnow()
    ticket.scan_count = (ticket.scan_count or 0) + 1
    await db.flush()

    profile = await get_profile(db, ticket.sponsor_user_id)
    cats = await get_won_categories(db, event_id, ticket.sponsor_user_id)

    return {
        "ticket_id": ticket.id,
        "receipt_number": ticket.receipt_number,
        "company_name": profile.company_name if profile else "Unknown",
        "contact_name": profile.contact_name if profile else "",
        "categories": cats,
        "category_names": [c["name"] for c in cats],
        "category_count": len(cats),
        "already_scanned": already_scanned,
        "scan_count": ticket.scan_count,
    }


# ── Organizer: sponsors funding my events ──

async def get_organizer_sponsors(
    db: AsyncSession, organizer_id: int, *, offset: int = 0, limit: int = 20,
) -> list[dict]:
    """Distinct sponsors with active bids on any of this organizer's events."""
    from sqlalchemy import distinct, func
    from sqlalchemy.orm import selectinload

    active = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]

    q = (
        select(
            SponsorBid.sponsor_user_id,
            func.count(SponsorBid.id).label("total_bids"),
            func.sum(SponsorBid.amount_cents).label("total_amount_cents"),
        )
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .join(Event, SponsorshipCategory.event_id == Event.id)
        .where(
            Event.organizer_id == organizer_id,
            SponsorBid.status.in_(active),
        )
        .group_by(SponsorBid.sponsor_user_id)
        .order_by(func.sum(SponsorBid.amount_cents).desc())
        .offset(offset)
        .limit(limit)
    )
    rows = (await db.execute(q)).all()

    result = []
    for r in rows:
        uid = r.sponsor_user_id
        profile = await get_profile(db, uid)
        user = (await db.execute(
            select(User).where(User.id == uid)
        )).scalar_one_or_none()

        if profile:
            name = profile.company_name
            contact = profile.contact_name
            logo = profile.logo_url
        else:
            name = user.display_name if user else "Unknown"
            contact = user.display_name or "" if user else ""
            logo = None

        result.append({
            "sponsor_user_id": uid,
            "company_name": name,
            "contact_name": contact,
            "logo_url": logo,
            "total_bids": r.total_bids,
            "total_amount_cents": r.total_amount_cents or 0,
        })
    return result


async def get_sponsor_events_for_organizer(
    db: AsyncSession, organizer_id: int, sponsor_user_id: int
) -> list[dict]:
    """Events where a specific sponsor has active bids, for this organizer."""
    from sqlalchemy import distinct, func
    from sqlalchemy.orm import selectinload

    active = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]

    event_ids_q = (
        select(distinct(SponsorshipCategory.event_id))
        .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
        .join(Event, SponsorshipCategory.event_id == Event.id)
        .where(
            Event.organizer_id == organizer_id,
            SponsorBid.sponsor_user_id == sponsor_user_id,
            SponsorBid.status.in_(active),
        )
    )

    events = list((await db.execute(
        select(Event)
        .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
        .where(Event.id.in_(event_ids_q))
        .order_by(Event.created_at.desc())
    )).scalars().all())

    result = []
    for e in events:
        summary = await get_sponsor_bid_summary_for_event(db, e.id, sponsor_user_id)
        cats_q = (
            select(
                SponsorshipCategory.name,
                SponsorBid.amount_cents,
                SponsorBid.status,
            )
            .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorshipCategory.event_id == e.id,
                SponsorBid.sponsor_user_id == sponsor_user_id,
                SponsorBid.status.in_(active),
            )
        )
        cat_rows = (await db.execute(cats_q)).all()
        bids_detail = [
            {"category": r.name, "amount_cents": r.amount_cents, "status": r.status.value}
            for r in cat_rows
        ]
        total_cents = sum(b["amount_cents"] for b in bids_detail)
        venue = e.venue
        result.append({
            "event_id": e.id,
            "title": e.title,
            "status": e.status.value,
            "start_time": e.start_time.isoformat() if e.start_time else None,
            "venue_name": venue.name if venue else None,
            "venue_city": venue.city if venue else None,
            "bid_summary": summary,
            "bids": bids_detail,
            "total_amount_cents": total_cents,
        })
    return result


# ── Public Carousel ──

async def get_paid_sponsors(db: AsyncSession, event_id: int) -> list[dict]:
    """Return company_name + logo_url for sponsors with paid bids on this event."""
    q = (
        select(
            SponsorBid.sponsor_user_id,
            SponsorProfile.company_name,
            SponsorProfile.logo_url,
            SponsorProfile.website_url,
        )
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .join(SponsorProfile, SponsorBid.sponsor_user_id == SponsorProfile.user_id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorBid.status == BidStatus.paid,
        )
        .group_by(
            SponsorBid.sponsor_user_id,
            SponsorProfile.company_name,
            SponsorProfile.logo_url,
            SponsorProfile.website_url,
        )
    )
    rows = (await db.execute(q)).all()
    return [
        {
            "sponsor_user_id": r.sponsor_user_id,
            "company_name": r.company_name,
            "logo_url": r.logo_url,
            "website_url": r.website_url,
        }
        for r in rows
    ]
