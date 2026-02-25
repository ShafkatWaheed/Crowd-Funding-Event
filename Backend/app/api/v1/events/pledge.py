"""
Event pledge: preview, pledge, unpledge, receipt, refund-status, funding, escrow.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.dependencies import CurrentUser, DbSession, require_role
from app.models.funding import Funding, FundingStatus
from app.models.user import User, UserRole
from app.schemas import (
    FundingSummaryResponse,
    PledgeBody,
    PledgePreviewResponse,
    PledgeReceiptResponse,
    PledgeResponse,
    UnpledgeResponse,
)
from app.core.exceptions import ForbiddenError, NotFoundError
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import escrow as escrow_service
from app.services import platform_settings as settings_svc
from app.services import notification_service as notif_svc
from app.models.notification import NotificationType
from app.rate_limit import limiter

from ._helpers import _build_tier_reservation_response

router = APIRouter()


@router.get("/{event_id}/pledge-preview", response_model=PledgePreviewResponse)
async def get_pledge_preview(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
    amount_cents: int = Query(0, ge=0),
    reserved_spots: int = Query(0, ge=0),
):
    """Preview invoice before confirming a pledge."""
    preview = await funding_service.pledge_preview(
        db,
        event_id=event_id,
        user=current_user,
        amount_cents=amount_cents,
        reserved_spots=reserved_spots,
    )
    return PledgePreviewResponse(**preview)


@router.post("/{event_id}/pledge")
@limiter.limit("20/minute")
async def pledge_event(
    request: Request,
    event_id: int,
    body: PledgeBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
):
    """Pledge/donate to event. Only allowed during approved (funding active) status."""
    from app.models.event import EventStatus
    event = await event_service.get_or_404(db, event_id)
    if event.status not in (EventStatus.approved,):
        raise HTTPException(status_code=409, detail="Pledging is only allowed during the funding period")

    tier_res = None
    if body.tier_reservations:
        tier_res = [{"tier_id": tr.tier_id, "spots": tr.spots} for tr in body.tier_reservations]

    pledge = await funding_service.create_pledge(
        db,
        event_id=event_id,
        user=current_user,
        amount_cents=body.amount_cents,
        reserved_spots=body.reserved_spots,
        tier_reservations=tier_res,
    )
    await notif_svc.create_notification(
        db, user_id=current_user.id,
        type=NotificationType.pledge_confirmed,
        title="Pledge Confirmed",
        message=f"Your pledge of ${body.amount_cents / 100:.2f} has been recorded.",
        data={"event_id": event_id, "pledge_id": pledge.id},
    )
    await db.commit()
    tier_resp = await _build_tier_reservation_response(db, pledge.id)
    return PledgeResponse(
        id=pledge.id,
        event_id=pledge.event_id,
        user_id=pledge.user_id,
        amount_cents=pledge.amount_cents,
        platform_cut_cents=pledge.platform_cut_cents,
        net_to_organizer_cents=pledge.net_to_organizer_cents,
        reserved_spots=pledge.reserved_spots,
        tier_reservations=tier_resp,
        receipt_number=pledge.receipt_number,
        status=pledge.status.value,
        is_guest=pledge.is_guest,
        created_at=pledge.created_at,
    )


@router.get("/{event_id}/pledges/{pledge_id}/receipt", response_model=PledgeReceiptResponse)
async def get_pledge_receipt(
    event_id: int,
    pledge_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Get a pledge receipt."""
    pledge = (await db.execute(
        select(Funding)
        .where(Funding.id == pledge_id, Funding.event_id == event_id)
        .options(selectinload(Funding.user))
    )).scalar_one_or_none()
    if not pledge:
        raise NotFoundError("Pledge", pledge_id)
    is_own_pledge = pledge.user_id == current_user.id
    is_event_organizer = False
    if current_user.role in (UserRole.organizer, UserRole.admin):
        event_check = await event_service.get_or_404(db, event_id)
        is_event_organizer = event_check.organizer_id == current_user.id or current_user.role == UserRole.admin
    if not is_own_pledge and not is_event_organizer:
        raise ForbiddenError("You can only view your own pledge receipts or pledges on your events")
    event = await event_service.get_or_404(db, event_id)
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")
    tier_resp = await _build_tier_reservation_response(db, pledge.id)
    backer_name = pledge.user.display_name if pledge.user and pledge.user.display_name else None
    return PledgeReceiptResponse(
        id=pledge.id,
        receipt_number=pledge.receipt_number,
        event_id=event_id,
        event_title=event.title,
        user_id=pledge.user_id,
        backer_name=backer_name,
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


@router.post("/{event_id}/unpledge", response_model=UnpledgeResponse)
async def unpledge_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
):
    """Unpledge from event (customer)."""
    result = await funding_service.unpledge(
        db,
        event_id=event_id,
        user=current_user,
    )
    return UnpledgeResponse(**result)


@router.get("/{event_id}/refund-status")
async def get_refund_status(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.sponsor)),
):
    """Poll refund status for the current user's pledges on this event."""
    processing = int((await db.execute(
        select(func.count()).where(
            Funding.event_id == event_id,
            Funding.user_id == current_user.id,
            Funding.status == FundingStatus.refund_processing,
        )
    )).scalar_one())

    completed = int((await db.execute(
        select(func.count()).where(
            Funding.event_id == event_id,
            Funding.user_id == current_user.id,
            Funding.status == FundingStatus.refunded,
        )
    )).scalar_one())

    failed = int((await db.execute(
        select(func.count()).where(
            Funding.event_id == event_id,
            Funding.user_id == current_user.id,
            Funding.status == FundingStatus.refund_failed,
        )
    )).scalar_one())

    if processing > 0:
        status = "processing"
    elif failed > 0:
        status = "failed"
    elif completed > 0:
        status = "completed"
    else:
        status = "none"

    return {
        "status": status,
        "processing_count": processing,
        "completed_count": completed,
        "failed_count": failed,
    }


@router.get("/{event_id}/funding")
async def get_event_funding(event_id: int, db: DbSession):
    """Funding summary for event (public or organizer/admin)."""
    summary = await funding_service.get_summary(db, event_id=event_id)
    return FundingSummaryResponse(**summary)


@router.get("/{event_id}/escrow")
async def get_event_escrow(event_id: int, db: DbSession):
    """Escrow summary for event (public)."""
    return await escrow_service.get_escrow_summary(db, event_id=event_id)
