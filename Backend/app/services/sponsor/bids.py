"""Sponsor bid place, update, withdraw, list, accept, reject."""
from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.user import User, UserRole
from app.models.sponsor import SponsorBid, BidStatus, SponsorshipCategory
from app.models.notification import NotificationType
from app.schemas.sponsor import BidCreate, BidUpdate
from app.repositories.sponsor_repo import sponsor_repo
from app.repositories.user_repo import user_repo
from app.services import notification_service as notif_svc
from app.worker.redis_pool import enqueue as arq_enqueue

from app.services.sponsor.categories import _get_category, _require_organizer
from app.services.sponsor.payments import _ensure_sponsor_ticket

logger = get_logger("svc.sponsor.bids")


async def place_bid(
    db: AsyncSession, cat_id: int, user: User, data: BidCreate
) -> SponsorBid:
    log_step(logger, "Place bid", cat_id=cat_id, user_id=user.id, amount_cents=data.amount_cents)
    if user.role != UserRole.sponsor:
        logger.warning("Place bid rejected: non-sponsor role", extra={"user_id": user.id})
        raise HTTPException(status_code=403, detail="Only sponsors can place bids")

    cat = await _get_category(db, cat_id)

    if data.amount_cents < cat.min_bid_cents:
        logger.warning("Place bid rejected: below min", extra={"cat_id": cat_id, "amount_cents": data.amount_cents, "min_cents": cat.min_bid_cents})
        raise HTTPException(
            status_code=400,
            detail=f"Bid must be at least {cat.min_bid_cents} cents (${cat.min_bid_cents / 100:.2f})",
        )
    if cat.filled_spots >= cat.total_spots:
        logger.warning("Place bid rejected: no spots", extra={"cat_id": cat_id})
        raise HTTPException(status_code=400, detail="No spots available in this category")

    active_statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
    my_active_bids = await sponsor_repo.count_active_bids_by_user(db, cat_id, user.id, active_statuses)

    if len(my_active_bids) >= cat.total_spots:
        logger.warning("Place bid rejected: max spots exceeded", extra={"cat_id": cat_id, "user_id": user.id})
        raise HTTPException(
            status_code=409,
            detail=f"You already have {len(my_active_bids)} active bid(s) — max is {cat.total_spots} (total spots)",
        )

    bid = SponsorBid(
        category_id=cat_id,
        sponsor_user_id=user.id,
        amount_cents=data.amount_cents,
        proposal_text=data.proposal_text,
    )
    bid = await sponsor_repo.create_bid(db, bid)

    event = await sponsor_repo.get_event(db, cat.event_id)
    if event:
        await notif_svc.create_notification(
            db, user_id=event.organizer_id,
            type=NotificationType.bid_received,
            title="New Sponsor Bid",
            message=f"A new bid of ${data.amount_cents / 100:.2f} was placed on '{cat.name}'.",
            data={"event_id": cat.event_id, "category_id": cat_id, "bid_id": bid.id},
        )

    logger.info("Bid placed", extra={"bid_id": bid.id, "cat_id": cat_id, "user_id": user.id})
    return bid


async def update_bid(
    db: AsyncSession, bid_id: int, user: User, data: BidUpdate
) -> SponsorBid:
    bid = await sponsor_repo.get_bid(db, bid_id)
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

    bid = await sponsor_repo.update_bid(db, bid)
    return bid


async def withdraw_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorBid:
    log_step(logger, "Withdraw bid", bid_id=bid_id, user_id=user.id)
    bid = await sponsor_repo.get_bid(db, bid_id)
    if not bid:
        logger.warning("Withdraw bid: not found", extra={"bid_id": bid_id})
        raise HTTPException(status_code=404, detail="Bid not found")
    if bid.sponsor_user_id != user.id:
        logger.warning("Withdraw bid: not owner", extra={"bid_id": bid_id, "user_id": user.id})
        raise HTTPException(status_code=403, detail="Not your bid")
    if bid.status != BidStatus.pending:
        logger.warning("Withdraw bid: not pending", extra={"bid_id": bid_id, "status": bid.status.value})
        raise HTTPException(status_code=400, detail="Can only withdraw pending bids")

    bid.status = BidStatus.withdrawn
    bid = await sponsor_repo.update_bid(db, bid)

    cat = await sponsor_repo.get_category(db, bid.category_id)
    if cat:
        event = await sponsor_repo.get_event(db, cat.event_id)
        if event:
            await notif_svc.create_notification(
                db, user_id=event.organizer_id,
                type=NotificationType.bid_rejected,
                title="Bid Withdrawn",
                message="A sponsor has withdrawn their bid.",
                data={"event_id": cat.event_id, "category_id": bid.category_id, "bid_id": bid_id},
            )

    logger.info("Bid withdrawn", extra={"bid_id": bid.id})
    return bid


async def list_bids(
    db: AsyncSession, cat_id: int, user: User
) -> list[SponsorBid]:
    """Organizer-only: list all bids for a category."""
    cat = await _get_category(db, cat_id)
    await _require_organizer(db, cat.event_id, user)
    return await sponsor_repo.list_bids_for_category(db, cat_id)


async def accept_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorBid:
    log_step(logger, "Accept bid", bid_id=bid_id, user_id=user.id)
    bid = await sponsor_repo.get_bid(db, bid_id)
    if not bid:
        logger.warning("Accept bid: not found", extra={"bid_id": bid_id})
        raise HTTPException(status_code=404, detail="Bid not found")

    # Lock the category to prevent race condition on filled_spots.
    # Offset 2_000_000 avoids collision with event-level advisory locks.
    await sponsor_repo.advisory_lock(db, bid.category_id + 2_000_000)
    cat = await sponsor_repo.get_category_for_update(db, bid.category_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")

    await _require_organizer(db, cat.event_id, user)

    if bid.status != BidStatus.pending:
        logger.warning("Accept bid: not pending", extra={"bid_id": bid_id, "status": bid.status.value})
        raise HTTPException(status_code=400, detail="Can only accept pending bids")
    if cat.filled_spots >= cat.total_spots:
        logger.warning("Accept bid: category full", extra={"bid_id": bid_id, "cat_id": bid.category_id})
        raise HTTPException(status_code=400, detail="No spots available — category is full")

    from app.models.prerequisite import UploadStatus
    required_prereqs = await sponsor_repo.list_required_prerequisites(db, bid.category_id)

    for prereq in required_prereqs:
        upload = await sponsor_repo.get_bid_prerequisite_upload(db, bid.id, prereq.id)
        if upload and upload.status == UploadStatus.pending:
            upload.status = UploadStatus.approved
            upload.reviewed_at = datetime.now(timezone.utc)

    bid.status = BidStatus.accepted
    cat.filled_spots += 1
    bid = await sponsor_repo.flush_and_refresh_bid(db, bid)

    await _ensure_sponsor_ticket(db, cat.event_id, bid.sponsor_user_id)

    await notif_svc.create_notification(
        db, user_id=bid.sponsor_user_id,
        type=NotificationType.bid_accepted,
        title="Bid Accepted",
        message="Your sponsorship bid has been accepted!",
        data={"event_id": cat.event_id, "category_id": bid.category_id, "bid_id": bid.id},
    )

    sponsor = await user_repo.get_by_id(db, bid.sponsor_user_id)
    event = await sponsor_repo.get_event(db, cat.event_id)
    if sponsor and sponsor.email:
        await arq_enqueue(
            "send_sponsor_bid_approved_email",
            sponsor_email=sponsor.email,
            sponsor_name=sponsor.display_name or "",
            event_title=event.title if event else f"Event #{cat.event_id}",
            category_name=cat.name,
            bid_amount_cents=bid.amount_cents,
        )

    # Add sponsor to announcement channel on acceptance
    try:
        from app.services.chat import channel_service
        await channel_service.add_member(db, event_id=cat.event_id, user_id=bid.sponsor_user_id, channel_type="sponsor")
    except Exception:
        logger.debug("Could not add sponsor to chat channel", extra={"event_id": cat.event_id, "user_id": bid.sponsor_user_id})

    logger.info("Bid accepted", extra={"bid_id": bid.id, "cat_id": bid.category_id})
    return bid


async def reject_bid(db: AsyncSession, bid_id: int, user: User) -> SponsorBid:
    log_step(logger, "Reject bid", bid_id=bid_id, user_id=user.id)
    bid = await sponsor_repo.get_bid(db, bid_id)
    if not bid:
        logger.warning("Reject bid: not found", extra={"bid_id": bid_id})
        raise HTTPException(status_code=404, detail="Bid not found")

    cat = await _get_category(db, bid.category_id)
    await _require_organizer(db, cat.event_id, user)

    if bid.status != BidStatus.pending:
        logger.warning("Reject bid: not pending", extra={"bid_id": bid_id, "status": bid.status.value})
        raise HTTPException(status_code=400, detail="Can only reject pending bids")

    bid.status = BidStatus.rejected
    bid = await sponsor_repo.update_bid(db, bid)

    await notif_svc.create_notification(
        db, user_id=bid.sponsor_user_id,
        type=NotificationType.bid_rejected,
        title="Bid Rejected",
        message="Your sponsorship bid was not accepted.",
        data={"event_id": cat.event_id, "category_id": bid.category_id, "bid_id": bid.id},
    )

    sponsor = await user_repo.get_by_id(db, bid.sponsor_user_id)
    event = await sponsor_repo.get_event(db, cat.event_id)
    if sponsor and sponsor.email:
        await arq_enqueue(
            "send_sponsor_bid_rejected_email",
            sponsor_email=sponsor.email,
            sponsor_name=sponsor.display_name or "",
            event_title=event.title if event else f"Event #{cat.event_id}",
            category_name=cat.name,
            bid_amount_cents=bid.amount_cents,
        )

    # Revoke chat access on rejection
    try:
        from app.services.chat import conversation_service
        await conversation_service.revoke_access(db, user_id=bid.sponsor_user_id, event_id=cat.event_id)
    except Exception:
        logger.debug("Could not revoke chat access after bid rejection", extra={"user_id": bid.sponsor_user_id, "event_id": cat.event_id})

    logger.info("Bid rejected", extra={"bid_id": bid.id})
    return bid
