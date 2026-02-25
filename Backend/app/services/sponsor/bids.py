"""Sponsor bid place, update, withdraw, list, accept, reject."""
from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.sponsor import SponsorBid, BidStatus
from app.schemas.sponsor import BidCreate, BidUpdate

from app.services.sponsor.categories import _get_category, _require_organizer
from app.services.sponsor.payments import _ensure_sponsor_ticket


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
