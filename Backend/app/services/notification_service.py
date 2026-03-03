"""
In-app notification service.
"""
from __future__ import annotations

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationType
from app.repositories.notification_repo import notification_repo

from app.logger import get_logger

logger = get_logger("notifications")


async def create_notification(
    db: AsyncSession,
    *,
    user_id: int,
    type: NotificationType,
    title: str,
    message: str,
    data: dict[str, Any] | None = None,
) -> Notification:
    """Create a single notification for one user."""
    notif = await notification_repo.create_notification(
        db,
        user_id=user_id,
        type=type,
        title=title,
        message=message,
        data=data,
    )

    try:
        from app.worker.redis_pool import enqueue as arq_enqueue
        await arq_enqueue(
            "send_push_notification",
            user_id=user_id,
            title=title,
            body=message,
            data=data,
        )
    except Exception:
        logger.debug("Could not enqueue push notification for user %d", user_id)

    return notif


async def create_bulk_notifications(
    db: AsyncSession,
    *,
    user_ids: list[int],
    type: NotificationType,
    title: str,
    message: str,
    data: dict[str, Any] | None = None,
) -> int:
    """Create the same notification for multiple users. Returns count created."""
    unique_ids = list(set(user_ids))
    notifications_data = [
        {
            "user_id": uid,
            "type": type,
            "title": title,
            "message": message,
            "data": data,
        }
        for uid in unique_ids
    ]
    count = await notification_repo.create_bulk_notifications(
        db, notifications_data=notifications_data,
    )
    logger.info("Created %d notifications of type %s", count, type.value)

    try:
        from app.worker.redis_pool import enqueue as arq_enqueue
        await arq_enqueue(
            "send_push_notification_bulk",
            user_ids=unique_ids,
            title=title,
            body=message,
            data=data,
        )
    except Exception:
        logger.debug("Could not enqueue bulk push for %d users", len(unique_ids))

    return count


async def list_notifications(
    db: AsyncSession,
    *,
    user_id: int,
    unread_only: bool = False,
    offset: int = 0,
    limit: int = 20,
) -> list[Notification]:
    return await notification_repo.list_notifications(
        db, user_id, unread_only=unread_only, offset=offset, limit=limit,
    )


async def unread_count(db: AsyncSession, *, user_id: int) -> int:
    return await notification_repo.get_unread_count(db, user_id)


async def mark_read(db: AsyncSession, *, notification_id: int, user_id: int) -> bool:
    return await notification_repo.mark_read(db, notification_id, user_id)


async def mark_all_read(db: AsyncSession, *, user_id: int) -> int:
    return await notification_repo.mark_all_read(db, user_id)


async def delete_notification(db: AsyncSession, *, notification_id: int, user_id: int) -> None:
    await notification_repo.delete_notification_row(db, notification_id, user_id)


async def register_device_token(
    db: AsyncSession, *, user_id: int, token: str, platform: str
) -> None:
    """Upsert a device token for push notifications."""
    existing = await notification_repo.get_device_token(db, token)
    if existing:
        existing.user_id = user_id
        existing.platform = platform
        await notification_repo.flush(db)
    else:
        await notification_repo.create_device_token(
            db, user_id=user_id, token=token, platform=platform,
        )
