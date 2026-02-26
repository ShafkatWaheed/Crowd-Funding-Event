"""
In-app notification endpoints.
"""
from fastapi import APIRouter, Query, Response

from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.services import notification_service as notif_svc

router = APIRouter()


@router.get("/notifications")
async def list_notifications(
    db: ReadDbSession,
    current_user: CurrentUser,
    unread_only: bool = Query(False),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List notifications for the current user, newest first."""
    items = await notif_svc.list_notifications(
        db, user_id=current_user.id, unread_only=unread_only,
        offset=offset, limit=limit,
    )
    return [
        {
            "id": n.id,
            "type": n.type.value,
            "title": n.title,
            "message": n.message,
            "data": n.data,
            "is_read": n.is_read,
            "created_at": n.created_at.isoformat() if n.created_at else None,
        }
        for n in items
    ]


@router.get("/notifications/unread-count")
async def get_unread_count(db: ReadDbSession, current_user: CurrentUser):
    """Get the number of unread notifications."""
    count = await notif_svc.unread_count(db, user_id=current_user.id)
    return {"unread_count": count}


@router.patch("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Mark a single notification as read."""
    ok = await notif_svc.mark_read(db, notification_id=notification_id, user_id=current_user.id)
    return {"success": ok}


@router.patch("/notifications/read-all")
async def mark_all_notifications_read(db: DbSession, current_user: CurrentUser):
    """Mark all notifications as read for the current user."""
    count = await notif_svc.mark_all_read(db, user_id=current_user.id)
    return {"marked_read": count}


@router.delete("/notifications/{notification_id}", status_code=204)
async def delete_notification(
    notification_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Delete a single notification. Only the owner can delete."""
    await notif_svc.delete_notification(db, notification_id=notification_id, user_id=current_user.id)
