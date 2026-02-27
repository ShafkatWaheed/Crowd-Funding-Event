"""
FCM push notification service.

Uses firebase_admin.messaging to deliver push notifications.
Checks the push_notifications_enabled platform setting before sending.
Automatically cleans up stale tokens (UNREGISTERED).
"""
from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device_token import DeviceToken

logger = logging.getLogger("push_notification")


async def send_push(
    db: AsyncSession,
    *,
    user_id: int,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> int:
    """Send a push notification to all devices for a single user.
    Returns the number of successfully sent messages."""
    from app.services import platform_settings as ps

    if not await ps.get_bool(db, "push_notifications_enabled"):
        return 0

    tokens = (await db.execute(
        select(DeviceToken).where(DeviceToken.user_id == user_id)
    )).scalars().all()

    if not tokens:
        return 0

    return await _send_to_tokens(db, tokens, title, body, data)


async def send_push_bulk(
    db: AsyncSession,
    *,
    user_ids: list[int],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> int:
    """Send a push notification to all devices for multiple users."""
    from app.services import platform_settings as ps

    if not await ps.get_bool(db, "push_notifications_enabled"):
        return 0

    unique_ids = list(set(user_ids))
    tokens = (await db.execute(
        select(DeviceToken).where(DeviceToken.user_id.in_(unique_ids))
    )).scalars().all()

    if not tokens:
        return 0

    return await _send_to_tokens(db, tokens, title, body, data)


async def _send_to_tokens(
    db: AsyncSession,
    tokens: list[DeviceToken],
    title: str,
    body: str,
    data: dict[str, Any] | None,
) -> int:
    """Send via FCM and clean up stale tokens."""
    try:
        from firebase_admin import messaging
        from app.core.firebase import get_firebase_app
        get_firebase_app()
    except (ImportError, ValueError) as e:
        logger.warning("FCM not available: %s", e)
        return 0

    str_data = {k: str(v) for k, v in (data or {}).items()}

    messages = [
        messaging.Message(
            token=dt.token,
            notification=messaging.Notification(title=title, body=body),
            data=str_data if str_data else None,
        )
        for dt in tokens
    ]

    try:
        response = messaging.send_each(messages)
    except Exception:
        logger.exception("FCM send_each failed for %d tokens", len(messages))
        return 0

    stale_token_ids: list[int] = []
    success_count = 0

    for i, send_response in enumerate(response.responses):
        if send_response.success:
            success_count += 1
        elif send_response.exception:
            code = getattr(send_response.exception, "code", "")
            if code == "UNREGISTERED" or "not-registered" in str(send_response.exception):
                stale_token_ids.append(tokens[i].id)
                logger.info("Removing stale token id=%d", tokens[i].id)

    if stale_token_ids:
        await db.execute(
            delete(DeviceToken).where(DeviceToken.id.in_(stale_token_ids))
        )
        await db.flush()

    logger.info(
        "FCM: sent %d/%d, stale removed %d",
        success_count, len(messages), len(stale_token_ids),
    )
    return success_count
