"""
In-app notification endpoints + device token management for FCM push.
"""
from fastapi import APIRouter, HTTPException, Query, Response
from pydantic import BaseModel
from sqlalchemy import select, delete as sa_delete

from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.models.device_token import DeviceToken
from app.services import notification_service as notif_svc

router = APIRouter()


class DeviceTokenBody(BaseModel):
    token: str
    platform: str = "web"


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


# ── Device tokens (FCM push) ──

@router.post("/me/device-tokens")
async def register_device_token(
    body: DeviceTokenBody,
    db: DbSession,
    current_user: CurrentUser,
):
    """Register or update a device token for push notifications."""
    if body.platform not in ("android", "ios", "web"):
        raise HTTPException(status_code=400, detail="platform must be android, ios, or web")
    existing = (await db.execute(
        select(DeviceToken).where(DeviceToken.token == body.token)
    )).scalar_one_or_none()
    if existing:
        existing.user_id = current_user.id
        existing.platform = body.platform
    else:
        db.add(DeviceToken(user_id=current_user.id, token=body.token, platform=body.platform))
    await db.flush()
    return {"ok": True}


@router.delete("/me/device-tokens/{token}")
async def unregister_device_token(
    token: str,
    db: DbSession,
    current_user: CurrentUser,
):
    """Remove a device token (e.g. on logout)."""
    await db.execute(
        sa_delete(DeviceToken).where(
            DeviceToken.token == token,
            DeviceToken.user_id == current_user.id,
        )
    )
    return {"ok": True}
