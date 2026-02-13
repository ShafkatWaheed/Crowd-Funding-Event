"""
Admin: approve/reject events, list pending, stats, platform settings.
"""
from fastapi import APIRouter, Depends

from app.dependencies import DbSession, require_role
from app.models.user import User, UserRole
from app.schemas import AdminEventItem, AdminStats, AdminUserItem, ApproveBody, PlatformSettingItem, PlatformSettingUpdate
from app.services import admin as admin_service
from app.services import platform_settings as settings_service

router = APIRouter()


@router.get("/users", response_model=list[AdminUserItem])
async def admin_list_users(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List all users (admin only)."""
    users = await admin_service.list_users(db)
    return [
        AdminUserItem(
            id=u.id,
            email=u.email,
            display_name=u.display_name,
            role=u.role.value,
            created_at=u.created_at,
        )
        for u in users
    ]


@router.get("/events", response_model=list[AdminEventItem])
async def admin_list_events(
    db: DbSession,
    status: str | None = None,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List events for admin (e.g. status=pending_approval)."""
    events = await admin_service.list_events_for_admin(db, status=status)
    return [
        AdminEventItem(
            id=e.id,
            title=e.title,
            status=e.status.value,
            organizer_id=e.organizer_id,
        )
        for e in events
    ]


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
    return {"ok": True, "event_id": event.id, "status": event.status.value}


@router.get("/stats", response_model=AdminStats)
async def admin_stats(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Platform stats including commission totals."""
    stats = await admin_service.get_stats(db)
    return AdminStats(**stats)


# ----- Platform Settings -----
@router.get("/settings", response_model=list[PlatformSettingItem])
async def get_settings(
    db: DbSession,
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
    return PlatformSettingItem(key=setting.key, value=setting.value, description=setting.description)


# ----- Escrow Management (Admin) -----
from app.services import escrow as escrow_service


@router.get("/escrows")
async def list_escrows(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """List all fund escrows (admin only)."""
    return await escrow_service.list_all_escrows(db)


@router.post("/escrows/{event_id}/release/{stage}")
async def admin_release_stage(
    event_id: int,
    stage: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin manually releases a specific escrow stage."""
    if stage == 1:
        escrow = await escrow_service.release_stage1(db, event_id=event_id, released_by="admin")
    elif stage == 2:
        escrow = await escrow_service.release_stage2(db, event_id=event_id, released_by="admin")
    elif stage == 3:
        escrow = await escrow_service.release_stage3(db, event_id=event_id, released_by="admin")
    else:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Stage must be 1, 2, or 3")
    return await escrow_service.get_escrow_summary(db, event_id=event_id)


@router.post("/escrows/{event_id}/freeze")
async def freeze_escrow(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin freezes an event's escrow payouts."""
    await escrow_service.freeze(db, event_id=event_id)
    return await escrow_service.get_escrow_summary(db, event_id=event_id)


@router.post("/escrows/{event_id}/unfreeze")
async def unfreeze_escrow(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin unfreezes an event's escrow payouts."""
    await escrow_service.unfreeze(db, event_id=event_id)
    return await escrow_service.get_escrow_summary(db, event_id=event_id)


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
