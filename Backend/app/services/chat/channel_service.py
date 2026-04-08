"""Business logic for announcement channels."""
from __future__ import annotations

import time
from typing import Any

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.chat import ChatChannel
from app.repositories.chat_repo import chat_channel_repo
from app.repositories.firebase_chat_repo import firebase_chat_repo

logger = get_logger("svc.chat.channel")


async def create_channel(
    db: AsyncSession,
    *,
    organizer_id: int,
    event_id: int,
    channel_type: str,
) -> ChatChannel:
    """Create an announcement channel for an event.

    Idempotent — returns existing channel if one already exists.
    Adds organizer + co-organizers + eligible audience as members.
    """
    log_step(logger, "Create channel", event_id=event_id, type=channel_type)

    from app.services import event as event_svc

    event = await event_svc.get_or_404(db, event_id)
    if not await _is_organizer_or_co(db, event, organizer_id):
        raise HTTPException(status_code=403, detail="Not an organizer for this event")

    channel_id = f"event_{event_id}_{channel_type}"
    existing = await chat_channel_repo.get_by_channel_id(db, channel_id)
    if existing:
        return existing

    now_ms = int(time.time() * 1000)
    firebase_chat_repo.create_channel(channel_id, {
        "event_id": event_id,
        "organizer_user_id": organizer_id,
        "type": channel_type,
        "status": "open",
        "created_at": now_ms,
        "last_post_at": None,
    })

    channel = ChatChannel(
        channel_id=channel_id,
        event_id=event_id,
        organizer_user_id=organizer_id,
        type=channel_type,
        status="open",
    )
    channel = await chat_channel_repo.create_channel(db, channel)

    await _add_organizers_as_members(db, event, channel_id)
    await _add_eligible_audience(db, event_id, channel_type, channel_id)

    logger.info("Channel created", extra={"channel_id": channel_id})
    return channel


async def create_post(
    db: AsyncSession,
    *,
    organizer_id: int,
    channel_id: str,
    body: str,
    msg_type: str = "text",
) -> dict[str, Any]:
    """Create an announcement post in a channel. Organizer/co-organizer only."""
    log_step(logger, "Create post", channel_id=channel_id)

    channel = await chat_channel_repo.get_by_channel_id(db, channel_id)
    if not channel:
        raise HTTPException(status_code=404, detail="Channel not found")
    if channel.status != "open":
        raise HTTPException(status_code=409, detail="Channel is read-only")

    from app.services import event as event_svc

    event = await event_svc.get_or_404(db, channel.event_id)
    if not await _is_organizer_or_co(db, event, organizer_id):
        raise HTTPException(status_code=403, detail="Not an organizer for this event")

    now_ms = int(time.time() * 1000)
    post_data = {
        "sender_id": organizer_id,
        "body": body,
        "msg_type": msg_type,
        "image_url": None,
        "created_at": now_ms,
        "reaction_counts": {"like": 0, "dislike": 0},
    }
    post_id = firebase_chat_repo.create_post(channel_id, post_data)
    firebase_chat_repo.update_last_post_at(channel_id, now_ms)

    await _notify_channel_members(db, channel, body)

    post_data["post_id"] = post_id
    post_data["channel_id"] = channel_id
    logger.info("Post created", extra={"channel_id": channel_id, "post_id": post_id})
    return post_data


async def attach_image(
    db: AsyncSession,
    *,
    organizer_id: int,
    channel_id: str,
    post_id: str,
    image_url: str,
) -> None:
    """Attach an uploaded image URL to an existing post."""
    channel = await chat_channel_repo.get_by_channel_id(db, channel_id)
    if not channel:
        raise HTTPException(status_code=404, detail="Channel not found")

    from app.services import event as event_svc

    event = await event_svc.get_or_404(db, channel.event_id)
    if not await _is_organizer_or_co(db, event, organizer_id):
        raise HTTPException(status_code=403, detail="Not an organizer")

    firebase_chat_repo.update_post_image(channel_id, post_id, image_url)


async def add_member(
    db: AsyncSession,
    *,
    event_id: int,
    user_id: int,
    channel_type: str,
) -> None:
    """Add a user to a channel. Idempotent — safe to call multiple times."""
    channel_id = f"event_{event_id}_{channel_type}"
    channel = await chat_channel_repo.get_by_channel_id(db, channel_id)
    if not channel:
        return

    from app.repositories.user_repo import user_repo

    user = await user_repo.get_by_id(db, user_id)
    if not user or not user.firebase_uid:
        logger.warning("Cannot add member: no firebase_uid", extra={"user_id": user_id})
        return

    firebase_chat_repo.add_channel_member(channel_id, user.firebase_uid)
    logger.debug("Member added to channel", extra={"channel_id": channel_id, "user_id": user_id})


async def remove_member(
    db: AsyncSession,
    *,
    event_id: int,
    user_id: int,
    channel_type: str,
) -> None:
    """Remove a user from a channel."""
    channel_id = f"event_{event_id}_{channel_type}"

    from app.repositories.user_repo import user_repo

    user = await user_repo.get_by_id(db, user_id)
    if not user or not user.firebase_uid:
        return

    firebase_chat_repo.remove_channel_member(channel_id, user.firebase_uid)
    logger.debug("Member removed from channel", extra={"channel_id": channel_id, "user_id": user_id})


async def close_event_channels(
    db: AsyncSession,
    *,
    event_id: int,
) -> None:
    """Mark all channels for an event as read_only."""
    channels = await chat_channel_repo.list_by_event(db, event_id)
    for ch in channels:
        await chat_channel_repo.update_status(db, ch.channel_id, "read_only")
        firebase_chat_repo.update_channel_status(ch.channel_id, "read_only")
    logger.info("Closed channels for event", extra={"event_id": event_id, "count": len(channels)})


# ── Helpers ──────────────────────────────────────────────────


async def _is_organizer_or_co(db: AsyncSession, event, user_id: int) -> bool:
    """Check if user is the primary organizer or a co-organizer."""
    if event.organizer_id == user_id:
        return True
    from app.repositories.event_repo import event_repo

    co_ids = await event_repo.get_co_organizer_ids(db, event.id)
    return user_id in co_ids


async def _add_organizers_as_members(db, event, channel_id: str) -> None:
    """Add primary organizer + all co-organizers to channel_members."""
    from app.repositories.user_repo import user_repo
    from app.repositories.event_repo import event_repo

    org_ids = [event.organizer_id]
    co_ids = await event_repo.get_co_organizer_ids(db, event.id)
    org_ids.extend(co_ids)

    for uid in org_ids:
        user = await user_repo.get_by_id(db, uid)
        if user and user.firebase_uid:
            firebase_chat_repo.add_channel_member(channel_id, user.firebase_uid)


async def _add_eligible_audience(
    db: AsyncSession, event_id: int, channel_type: str, channel_id: str
) -> None:
    """Add all eligible users to the channel based on channel type."""
    from app.repositories.user_repo import user_repo

    if channel_type == "customer":
        from app.repositories.funding_repo import funding_repo
        from app.repositories.ticket_repo import ticket_repo

        pledger_ids = await funding_repo.get_pledger_ids(db, event_id)
        ticket_holder_ids = await ticket_repo.get_ticket_holder_user_ids(db, event_id)
        user_ids = set(pledger_ids) | set(ticket_holder_ids)
    else:
        from app.repositories.sponsor_repo import sponsor_repo

        user_ids = set(
            await sponsor_repo.get_accepted_sponsor_user_ids(db, event_id)
        )

    for uid in user_ids:
        user = await user_repo.get_by_id(db, uid)
        if user and user.firebase_uid:
            firebase_chat_repo.add_channel_member(channel_id, user.firebase_uid)


async def _notify_channel_members(
    db: AsyncSession, channel: ChatChannel, body: str
) -> None:
    """Send FCM push to all channel members."""
    from app.services import notification_service as notif_svc
    from app.models.notification import NotificationType

    members = firebase_chat_repo.get_channel_members(channel.channel_id)
    if not members:
        return

    from app.repositories.user_repo import user_repo

    user_ids = []
    for firebase_uid in members:
        user = await user_repo.get_by_firebase_uid(db, firebase_uid)
        if user and user.id != channel.organizer_user_id:
            user_ids.append(user.id)

    if user_ids:
        truncated = body[:100] + "..." if len(body) > 100 else body
        await notif_svc.create_bulk_notifications(
            db,
            user_ids=user_ids,
            type=NotificationType.chat_message,
            title="New Announcement",
            message=truncated,
            data={"channel_id": channel.channel_id},
        )
