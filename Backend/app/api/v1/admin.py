"""
Admin: approve/reject events, list pending, stats, platform settings.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel as _BaseModel

from app.dependencies import DbSession, ReadDbSession, require_role
from app.logger import get_logger, log_step
from app.rate_limit import limiter
from app.services import audit as audit_svc

from app.models.user import User, UserRole
from app.models.notification import NotificationType
from app.repositories.event_repo import event_repo as ev_repo
from app.repositories.escrow_repo import escrow_repo
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
from app.schemas.admin import AdminUserDetailResponse
from app.services import admin as admin_service
from app.services import platform_settings as settings_service
from app.services import notification_service as notif_svc
from app.services import ticket as ticket_service
from app.services import funding as funding_service

logger = get_logger("api.admin")
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
    return await admin_service.get_user_detail(db, user_id)


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
    log_step(logger, "Approving event", event_id=event_id, admin_id=current_user.id, approved=body.approved)
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
    from app.cache import invalidate_event_cascade
    await invalidate_event_cascade(event_id)
    if body.approved:
        from app.worker.event_jobs import schedule_event_transitions
        await schedule_event_transitions(event)
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
    from app.cache import cache_get_or_compute, safe_cache_key
    from app.services.platform_settings import get_int as get_setting_int, get_float as get_setting_float

    cache_key = safe_cache_key("admin_dash", period, genre or "", status or "")

    async def _compute():
        return await admin_service.get_dashboard(
            db, period=period, genre=genre, status=status,
        )

    ttl = await get_setting_int(db, "cache_ttl_admin_dashboard")
    beta = await get_setting_float(db, "cache_beta_dashboard")
    return await cache_get_or_compute(cache_key, _compute, ttl=ttl, beta=beta)


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
    log_step(logger, "Updating setting", key=key, admin_id=current_user.id)
    setting = await settings_service.set_value(db, key, body.value)
    from app.api.v1.config import invalidate_public_config
    await invalidate_public_config()
    if key.startswith("rate_limit_"):
        from app.rate_limit import reload_rate_limits
        await reload_rate_limits(db)
    # Warn all admins when Stripe is enabled but not yet implemented
    if key == "stripe_enabled" and body.value == "true":
        from app.services.escrow_base import get_all_admin_ids
        admin_ids = await get_all_admin_ids(db)
        if admin_ids:
            await notif_svc.create_bulk_notifications(
                db, user_ids=admin_ids,
                type=NotificationType.settings_warning,
                title="Stripe Enabled — Not Yet Implemented",
                message=(
                    "Stripe has been enabled as the payment gateway but the integration "
                    "is not yet implemented. All payments, refunds, and payouts will fail "
                    "until the Stripe gateway is fully built. Disable stripe_enabled to "
                    "restore the mock gateway."
                ),
                data={"key": key, "value": body.value, "changed_by": current_user.id},
            )
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="settings_update",
        target_type="setting", target_id=key, details={"value": body.value},
    )
    logger.info("Setting updated", extra={"key": key, "admin_id": current_user.id})
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
    log_step(logger, "Admin refunding sponsor bid", event_id=event_id, bid_id=bid_id, admin_id=current_user.id)
    from app.services import sponsor as sponsor_svc
    payment = await sponsor_svc.refund_bid(db, bid_id, current_user)
    bid_obj = await sponsor_repo.get_bid(db, bid_id)
    sponsor_user_id = bid_obj.sponsor_user_id if bid_obj else None
    if sponsor_user_id:
        await notif_svc.create_notification(
            db, user_id=sponsor_user_id,
            type=NotificationType.sponsor_refunded,
            title="Sponsorship Refunded",
            message="Your sponsorship refund is being processed by an administrator.",
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
    log_step(logger, "Admin refunding pledge", event_id=event_id, funding_id=funding_id, admin_id=current_user.id)
    count = await funding_service.refund_pledge_by_id(db, event_id=event_id, funding_id=funding_id)
    if count == 0:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Pledge", funding_id)
    return {"ok": True, "event_id": event_id, "funding_id": funding_id}


# ----- Refund Retry (failed refunds) -----

@router.post("/refunds/ticket/{ticket_sale_id}/retry")
@limiter.limit("60/minute")
async def admin_retry_ticket_refund(
    request: Request,
    ticket_sale_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Re-enqueue a failed ticket refund."""
    from app.services import refund_retry
    await refund_retry.retry_ticket_refund(db, ticket_sale_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="refund_retry",
        target_type="ticket_sale", target_id=ticket_sale_id,
    )
    return {"ok": True, "status": "re-enqueued", "ticket_sale_id": ticket_sale_id}


@router.post("/refunds/pledge/{funding_id}/retry")
@limiter.limit("60/minute")
async def admin_retry_pledge_refund(
    request: Request,
    funding_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Re-enqueue a failed pledge refund."""
    from app.services import refund_retry
    await refund_retry.retry_pledge_refund(db, funding_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="refund_retry",
        target_type="funding", target_id=funding_id,
    )
    return {"ok": True, "status": "re-enqueued", "funding_id": funding_id}


@router.post("/refunds/sponsor/{payment_id}/retry")
@limiter.limit("60/minute")
async def admin_retry_sponsor_refund(
    request: Request,
    payment_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Re-enqueue a failed sponsor payment refund."""
    from app.services import refund_retry
    await refund_retry.retry_sponsor_refund(db, payment_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="refund_retry",
        target_type="sponsor_payment", target_id=payment_id,
    )
    return {"ok": True, "status": "re-enqueued", "payment_id": payment_id}


@router.post("/refunds/retry-all/{event_id}")
@limiter.limit("60/minute")
async def admin_retry_all_refunds(
    request: Request,
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Re-enqueue all failed refunds for an event."""
    from app.services import refund_retry
    counts = await refund_retry.retry_all_for_event(db, event_id)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="refund_retry_all",
        target_type="event", target_id=event_id, details=counts,
    )
    return {"ok": True, "event_id": event_id, **counts}


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
    await escrow_repo.flush_and_refresh(db, escrow)

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
    all_escrows = await escrow_repo.get_all_escrows_for_event(db, event_id)

    return {
        "event_id": event_id,
        "fund": _escrow_to_dict(all_escrows["fund"]) if all_escrows["fund"] else None,
        "ticket": _escrow_to_dict(all_escrows["ticket"]) if all_escrows["ticket"] else None,
        "sponsor": _escrow_to_dict(all_escrows["sponsor"]) if all_escrows["sponsor"] else None,
    }


@router.post("/organizers/{organizer_id}/freeze-payouts")
async def freeze_organizer_payouts(
    organizer_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin freezes all payout for an organizer (sets payout_frozen on all their events)."""
    count = await ev_repo.freeze_organizer_events(db, organizer_id)
    return {"ok": True, "events_frozen": count}


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
    log_step(logger, "Resolving event review", event_id=event_id, target_status=body.target_status, admin_id=current_user.id)
    from app.core.exceptions import NotFoundError
    event = await ev_repo.get_event_by_id_basic(db, event_id)
    if not event:
        raise NotFoundError("Event", event_id)
    result = await admin_service.resolve_review(
        db, event,
        target_status=body.target_status,
        notes=body.notes,
        admin_email=current_user.email,
    )
    if body.target_status == "approved":
        from app.worker.event_jobs import schedule_event_transitions
        await schedule_event_transitions(event)
    return result


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
    from app.repositories.worker_run_repo import worker_run_repo

    rows, total = await worker_run_repo.list_runs(
        db, task_name=task_name, status=status, offset=offset, limit=limit,
    )

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
    from app.repositories.worker_run_repo import worker_run_repo

    rows, last_status_map = await worker_run_repo.get_summary(db)

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


# ═══════════════════════════════════════
#  Per-Event Policy Overrides
# ═══════════════════════════════════════

class _PolicyOverrideBody(_BaseModel):
    admin_override_waitlist_max_size: int | None = None
    admin_override_event_max_images: int | None = None
    admin_override_max_posts_per_day: int | None = None
    admin_override_max_co_organizers: int | None = None
    admin_override_refund_deadline_percent: int | None = None


@router.patch("/events/{event_id}/policy-overrides")
async def admin_set_policy_overrides(
    event_id: int,
    body: _PolicyOverrideBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Set or clear admin per-event policy overrides. Null values clear the override."""
    from app.services import event as event_svc

    event = await event_svc.get_or_404(db, event_id)
    result = await admin_service.set_policy_overrides(
        db, event, body=body, admin_id=current_user.id,
    )
    # Rename key for backwards compat with existing API response shape
    result["effective"] = result.pop("effective_policy")
    return result


# ═══════════════════════════════════════
#  KYC Review
# ═══════════════════════════════════════

from app.schemas.kyc import KycDocumentResponse, KycPendingUser, KycVerifyBody
from app.services import kyc_verification as kyc_svc
from pathlib import Path


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


@router.get("/kyc-pending", response_model=list[KycPendingUser])
async def admin_list_kyc_pending(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List users with KYC status 'submitted' awaiting admin review."""
    users = await kyc_svc.list_pending_users(db)
    result = []
    for u in users:
        docs = await kyc_svc.list_documents(db, u.id)
        result.append(KycPendingUser(
            user_id=u.id,
            email=u.email,
            display_name=u.display_name,
            role=u.role.value,
            kyc_status=u.kyc_status,
            submitted_at=u.updated_at,
            document_count=len(docs),
        ))
    return result


@router.get("/users/{user_id}/kyc-documents", response_model=list[KycDocumentResponse])
async def admin_get_kyc_documents(
    user_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Get all KYC documents for a user (admin only)."""
    docs = await kyc_svc.list_documents(db, user_id)
    return [_kyc_doc_response(d) for d in docs]


@router.post("/users/{user_id}/kyc-verify")
async def admin_verify_kyc(
    user_id: int,
    body: KycVerifyBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Approve or reject a user's KYC submission."""
    log_step(logger, "Admin verifying KYC", user_id=user_id, approved=body.approved, admin_id=current_user.id)
    try:
        new_status = await kyc_svc.admin_verify(
            db,
            user_id=user_id,
            approved=body.approved,
            rejection_reason=body.rejection_reason,
            reviewed_by_id=current_user.id,
        )
        await audit_svc.log_action(
            db,
            admin_id=current_user.id,
            action="kyc_verify" if body.approved else "kyc_reject",
            target_type="user",
            target_id=user_id,
            details={"approved": body.approved, "reason": body.rejection_reason},
        )
        await db.commit()
    except ValueError as e:
        logger.warning("KYC verification failed", extra={"user_id": user_id, "error": str(e)})
        raise HTTPException(status_code=400, detail=str(e))
    return {"user_id": user_id, "kyc_status": new_status}
