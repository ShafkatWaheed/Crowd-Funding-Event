"""
Notification & device-token data-access layer.

All SQLAlchemy queries for notifications and FCM device tokens live here.
Services and routes must call these methods instead of db.execute() directly.
"""
from __future__ import annotations

from typing import Any, Sequence

from sqlalchemy import delete as sa_delete, func, select, update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device_token import DeviceToken
from app.models.notification import Notification, NotificationType
from app.repositories.base import BaseRepository


class NotificationRepository(BaseRepository[Notification]):
    model_class = Notification

    # ═══════════════════════════════════════════════════════════════════
    #  Notification CRUD
    # ═══════════════════════════════════════════════════════════════════

    async def create_notification(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        type: NotificationType,
        title: str,
        message: str,
        data: dict[str, Any] | None = None,
    ) -> Notification:
        """Create a single notification, flush, and refresh."""
        notif = Notification(
            user_id=user_id,
            type=type,
            title=title,
            message=message,
            data=data,
        )
        db.add(notif)
        await db.flush()
        await db.refresh(notif)
        return notif

    async def create_bulk_notifications(
        self,
        db: AsyncSession,
        *,
        notifications_data: list[dict[str, Any]],
    ) -> int:
        """
        Bulk-insert notifications from a list of dicts.

        Each dict should contain: user_id, type, title, message, and
        optionally data.  Returns the count of rows added.
        """
        for item in notifications_data:
            db.add(Notification(
                user_id=item["user_id"],
                type=item["type"],
                title=item["title"],
                message=item["message"],
                data=item.get("data"),
            ))
        await db.flush()
        return len(notifications_data)

    # ═══════════════════════════════════════════════════════════════════
    #  Notification Queries
    # ═══════════════════════════════════════════════════════════════════

    async def list_notifications(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        unread_only: bool = False,
        offset: int = 0,
        limit: int = 20,
    ) -> list[Notification]:
        """List notifications for a user, newest first, with optional filters."""
        q = select(Notification).where(Notification.user_id == user_id)
        if unread_only:
            q = q.where(Notification.is_read == False)  # noqa: E712
        q = q.order_by(Notification.created_at.desc()).offset(offset).limit(limit)
        return list((await db.execute(q)).scalars().all())

    async def get_unread_count(
        self,
        db: AsyncSession,
        user_id: int,
    ) -> int:
        """Return the number of unread notifications for a user."""
        q = select(func.count()).where(
            Notification.user_id == user_id,
            Notification.is_read == False,  # noqa: E712
        )
        return int((await db.execute(q)).scalar_one())

    async def mark_read(
        self,
        db: AsyncSession,
        notification_id: int,
        user_id: int,
    ) -> bool:
        """Mark a single notification as read. Returns True if a row was updated."""
        result = await db.execute(
            sa_update(Notification)
            .where(Notification.id == notification_id, Notification.user_id == user_id)
            .values(is_read=True)
        )
        return result.rowcount > 0

    async def mark_all_read(
        self,
        db: AsyncSession,
        user_id: int,
    ) -> int:
        """Mark all unread notifications as read. Returns the number of rows updated."""
        result = await db.execute(
            sa_update(Notification)
            .where(Notification.user_id == user_id, Notification.is_read == False)  # noqa: E712
            .values(is_read=True)
        )
        return result.rowcount

    async def get_notification(
        self,
        db: AsyncSession,
        notification_id: int,
        user_id: int,
    ) -> Notification | None:
        """Fetch a single notification by id, scoped to the owning user."""
        q = select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def delete_notification_row(
        self,
        db: AsyncSession,
        notification_id: int,
        user_id: int,
    ) -> None:
        """
        Delete a notification after verifying ownership.

        Raises NotFoundError if the notification does not exist and
        ForbiddenError if it belongs to a different user.
        """
        from app.core.exceptions import ForbiddenError, NotFoundError

        notif = (await db.execute(
            select(Notification).where(Notification.id == notification_id)
        )).scalar_one_or_none()
        if not notif:
            raise NotFoundError("Notification not found")
        if notif.user_id != user_id:
            raise ForbiddenError("Not your notification")
        await db.execute(
            sa_delete(Notification).where(Notification.id == notification_id)
        )

    # ═══════════════════════════════════════════════════════════════════
    #  Device Token CRUD
    # ═══════════════════════════════════════════════════════════════════

    async def get_device_token(
        self,
        db: AsyncSession,
        token: str,
    ) -> DeviceToken | None:
        """Look up a device token row by its token string value."""
        q = select(DeviceToken).where(DeviceToken.token == token)
        return (await db.execute(q)).scalar_one_or_none()

    async def create_device_token(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        token: str,
        platform: str,
    ) -> DeviceToken:
        """Insert a new device token row and flush."""
        dt = DeviceToken(user_id=user_id, token=token, platform=platform)
        db.add(dt)
        await db.flush()
        return dt

    async def delete_device_token(
        self,
        db: AsyncSession,
        user_id: int,
        token: str,
    ) -> None:
        """Delete a device token by user_id + token value."""
        await db.execute(
            sa_delete(DeviceToken).where(
                DeviceToken.token == token,
                DeviceToken.user_id == user_id,
            )
        )

    async def get_device_tokens_for_user(
        self,
        db: AsyncSession,
        user_id: int,
    ) -> list[DeviceToken]:
        """Return all device tokens registered for a user."""
        q = select(DeviceToken).where(DeviceToken.user_id == user_id)
        return list((await db.execute(q)).scalars().all())

    async def get_device_tokens_for_users(
        self,
        db: AsyncSession,
        user_ids: list[int],
    ) -> list[DeviceToken]:
        """Return all device tokens for multiple users."""
        if not user_ids:
            return []
        q = select(DeviceToken).where(DeviceToken.user_id.in_(user_ids))
        return list((await db.execute(q)).scalars().all())

    async def delete_stale_tokens(
        self,
        db: AsyncSession,
        token_ids: list[int],
    ) -> None:
        """Delete device tokens by their IDs (stale/unregistered cleanup)."""
        if not token_ids:
            return
        await db.execute(
            sa_delete(DeviceToken).where(DeviceToken.id.in_(token_ids))
        )
        await db.flush()

    # ── Cleanup helpers (worker tasks) ─────────────────────────────

    async def delete_notifications_before(self, db: AsyncSession, cutoff) -> int:
        """Delete notifications older than cutoff. Returns rowcount."""
        result = await db.execute(
            sa_delete(Notification).where(Notification.created_at < cutoff)
        )
        return result.rowcount

    async def delete_device_tokens_before(self, db: AsyncSession, cutoff) -> int:
        """Delete device tokens not updated since cutoff. Returns rowcount."""
        result = await db.execute(
            sa_delete(DeviceToken).where(DeviceToken.updated_at < cutoff)
        )
        return result.rowcount

    async def flush(self, db: AsyncSession) -> None:
        await db.flush()


# Module-level singleton
notification_repo = NotificationRepository()
