"""
In-app notification service.
"""
from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationType

logger = logging.getLogger("notifications")


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
    notif = Notification(
        user_id=user_id,
        type=type,
        title=title,
        message=message,
        data=data,
    )
    db.add(notif)
    await db.flush()

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
    for uid in unique_ids:
        db.add(Notification(
            user_id=uid,
            type=type,
            title=title,
            message=message,
            data=data,
        ))
    await db.flush()
    logger.info("Created %d notifications of type %s", len(unique_ids), type.value)

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

    return len(unique_ids)


async def list_notifications(
    db: AsyncSession,
    *,
    user_id: int,
    unread_only: bool = False,
    offset: int = 0,
    limit: int = 20,
) -> list[Notification]:
    q = select(Notification).where(Notification.user_id == user_id)
    if unread_only:
        q = q.where(Notification.is_read == False)  # noqa: E712
    q = q.order_by(Notification.created_at.desc()).offset(offset).limit(limit)
    return list((await db.execute(q)).scalars().all())


async def unread_count(db: AsyncSession, *, user_id: int) -> int:
    q = select(func.count()).where(
        Notification.user_id == user_id,
        Notification.is_read == False,  # noqa: E712
    )
    return (await db.execute(q)).scalar_one()


async def mark_read(db: AsyncSession, *, notification_id: int, user_id: int) -> bool:
    result = await db.execute(
        update(Notification)
        .where(Notification.id == notification_id, Notification.user_id == user_id)
        .values(is_read=True)
    )
    return result.rowcount > 0


async def mark_all_read(db: AsyncSession, *, user_id: int) -> int:
    result = await db.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read == False)  # noqa: E712
        .values(is_read=True)
    )
    return result.rowcount


async def delete_notification(db: AsyncSession, *, notification_id: int, user_id: int) -> None:
    from app.core.exceptions import NotFoundError, ForbiddenError
    notif = (await db.execute(
        select(Notification).where(Notification.id == notification_id)
    )).scalar_one_or_none()
    if not notif:
        raise NotFoundError("Notification not found")
    if notif.user_id != user_id:
        raise ForbiddenError("Not your notification")
    await db.execute(
        delete(Notification).where(Notification.id == notification_id)
    )
