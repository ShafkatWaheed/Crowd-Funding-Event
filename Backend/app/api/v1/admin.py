"""
Admin: approve/reject events, list pending, stats.
"""
from fastapi import APIRouter, Depends

from app.dependencies import CurrentUser, DbSession, require_role
from app.models.user import UserRole
from app.schemas import AdminEventItem, AdminStats, AdminUserItem, ApproveBody
from app.services import admin as admin_service

router = APIRouter()


@router.get("/users", response_model=list[AdminUserItem])
async def admin_list_users(
    db: DbSession,
    current_user: CurrentUser = Depends(require_role(UserRole.admin)),
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
    current_user: CurrentUser = Depends(require_role(UserRole.admin)),
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
    current_user: CurrentUser = Depends(require_role(UserRole.admin)),
):
    """Approve or reject event (admin). Approved -> status approved; reject -> back to draft."""
    event = await admin_service.approve_or_reject_event(
        db, event_id=event_id, approved=body.approved
    )
    return {"ok": True, "event_id": event.id, "status": event.status.value}


@router.get("/stats", response_model=AdminStats)
async def admin_stats(
    db: DbSession,
    current_user: CurrentUser = Depends(require_role(UserRole.admin)),
):
    """Basic platform stats (admin)."""
    stats = await admin_service.get_stats(db)
    return AdminStats(**stats)
