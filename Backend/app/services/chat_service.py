"""
Chat service: Redis Streams storage, Pub/Sub routing, archive/purge.

Messages are stored in Redis Streams (one per bid: chat:bid:{bid_id}).
Read cursors are stored in a Redis hash (chat:read:{bid_id}).
Only lightweight metadata (last_message_at, unread counts) touches PostgreSQL.
"""
from __future__ import annotations

import gzip
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import redis.asyncio as aioredis
from sqlalchemy import and_, select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.logger import get_logger
from app.models.event import Event, EventStatus
from app.models.sponsor import SponsorBid, BidStatus, SponsorshipCategory

logger = get_logger("chat")

STREAM_PREFIX = "chat:bid:"
READ_CURSOR_PREFIX = "chat:read:"
PUBSUB_PREFIX = "chat:bid:"
ARCHIVE_DIR = Path("static/archives/chat")

OPEN_BID_STATUSES = {BidStatus.pending, BidStatus.accepted, BidStatus.paid}
OPEN_EVENT_STATUSES = {
    EventStatus.approved,
    EventStatus.selling_tickets,
    EventStatus.waiting_event_date,
    EventStatus.live,
}


async def _get_redis() -> aioredis.Redis:
    return aioredis.from_url(settings.REDIS_URL, decode_responses=True, socket_connect_timeout=3)


async def validate_participant(db: AsyncSession, bid_id: int, user_id: int) -> dict[str, Any]:
    """Verify user is a participant in this bid and return context.

    Returns dict with bid, event, sponsor_user_id, organizer_user_id, is_writable.
    Raises ValueError if user is not a participant.
    """
    bid = await db.get(SponsorBid, bid_id)
    if not bid:
        raise ValueError("Bid not found")

    cat = await db.get(SponsorshipCategory, bid.category_id)
    if not cat or not cat.event_id:
        raise ValueError("Sponsorship category not linked to event")

    event = await db.get(Event, cat.event_id)
    if not event:
        raise ValueError("Event not found")

    is_sponsor = user_id == bid.sponsor_user_id
    is_organizer = user_id == event.organizer_id
    if not is_sponsor and not is_organizer:
        raise ValueError("Not a participant in this bid")

    is_writable = (
        bid.status in OPEN_BID_STATUSES
        and event.status in OPEN_EVENT_STATUSES
    )

    return {
        "bid": bid,
        "event": event,
        "sponsor_user_id": bid.sponsor_user_id,
        "organizer_user_id": event.organizer_id,
        "is_writable": is_writable,
        "is_sponsor": is_sponsor,
    }


async def send_message(
    bid_id: int,
    sender_id: int,
    body: str,
    client_id: str,
    msg_type: str = "text",
) -> dict[str, Any]:
    """Append a message to the bid's Redis Stream and publish to Pub/Sub."""
    r = await _get_redis()
    try:
        stream_key = f"{STREAM_PREFIX}{bid_id}"
        now_ms = int(time.time() * 1000)
        fields = {
            "sender_id": str(sender_id),
            "body": body,
            "client_id": client_id,
            "type": msg_type,
            "ts": str(now_ms),
        }
        from app.services import platform_settings as settings_svc
        from app.db.base import async_session_maker
        async with async_session_maker() as db:
            maxlen = await settings_svc.get_int(db, "chat_stream_maxlen")

        message_id = await r.xadd(stream_key, fields, maxlen=maxlen, approximate=True)

        payload = json.dumps({
            "type": "new_message",
            "message": {
                "id": message_id,
                "bid_id": bid_id,
                "sender_id": sender_id,
                "body": body,
                "client_id": client_id,
                "msg_type": msg_type,
                "created_at": now_ms,
            },
        })
        await r.publish(f"{PUBSUB_PREFIX}{bid_id}", payload)

        return {
            "id": message_id,
            "bid_id": bid_id,
            "sender_id": sender_id,
            "body": body,
            "client_id": client_id,
            "msg_type": msg_type,
            "created_at": now_ms,
        }
    finally:
        await r.aclose()


async def get_messages(
    bid_id: int,
    before_id: str | None = None,
    limit: int = 50,
) -> list[dict[str, Any]]:
    """Fetch message history from the Redis Stream (newest first)."""
    r = await _get_redis()
    try:
        stream_key = f"{STREAM_PREFIX}{bid_id}"
        end = before_id if before_id else "+"
        start = "-"
        raw = await r.xrevrange(stream_key, max=end, min=start, count=limit)
        messages = []
        for msg_id, fields in raw:
            if msg_id == before_id:
                continue
            messages.append({
                "id": msg_id,
                "bid_id": bid_id,
                "sender_id": int(fields.get("sender_id", 0)),
                "body": fields.get("body", ""),
                "client_id": fields.get("client_id", ""),
                "msg_type": fields.get("type", "text"),
                "created_at": int(fields.get("ts", 0)),
            })
        return messages
    finally:
        await r.aclose()


async def mark_read(bid_id: int, user_id: int, message_id: str) -> None:
    """Update the read cursor for a user on a bid chat."""
    r = await _get_redis()
    try:
        cursor_key = f"{READ_CURSOR_PREFIX}{bid_id}"
        await r.hset(cursor_key, str(user_id), message_id)
    finally:
        await r.aclose()


async def get_read_cursor(bid_id: int, user_id: int) -> str | None:
    """Get the last-read message ID for a user on a bid chat."""
    r = await _get_redis()
    try:
        cursor_key = f"{READ_CURSOR_PREFIX}{bid_id}"
        return await r.hget(cursor_key, str(user_id))
    finally:
        await r.aclose()


async def update_pg_metadata(
    db: AsyncSession,
    bid_id: int,
    sender_is_sponsor: bool,
) -> None:
    """Update lightweight chat metadata on the sponsor_bids row."""
    bid = await db.get(SponsorBid, bid_id)
    if not bid:
        return
    bid.last_message_at = datetime.now(timezone.utc)
    if sender_is_sponsor:
        bid.unread_count_organizer = (bid.unread_count_organizer or 0) + 1
    else:
        bid.unread_count_sponsor = (bid.unread_count_sponsor or 0) + 1
    await db.flush()


async def clear_unread(db: AsyncSession, bid_id: int, user_is_sponsor: bool) -> None:
    """Clear unread count for the reading user."""
    bid = await db.get(SponsorBid, bid_id)
    if not bid:
        return
    if user_is_sponsor:
        bid.unread_count_sponsor = 0
    else:
        bid.unread_count_organizer = 0
    await db.flush()


async def get_conversations(db: AsyncSession, user_id: int) -> list[dict[str, Any]]:
    """List bids with chat activity for the current user."""
    from sqlalchemy.orm import aliased
    from app.models.user import User

    SponsorUser = aliased(User)
    OrganizerUser = aliased(User)

    q = (
        select(SponsorBid, SponsorshipCategory, Event, SponsorUser, OrganizerUser)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .join(Event, SponsorshipCategory.event_id == Event.id)
        .join(SponsorUser, SponsorBid.sponsor_user_id == SponsorUser.id)
        .join(OrganizerUser, Event.organizer_id == OrganizerUser.id)
        .where(
            or_(
                # Sponsors see ALL their bids (even without messages yet)
                SponsorBid.sponsor_user_id == user_id,
                # Organizers only see bids with chat activity
                and_(
                    Event.organizer_id == user_id,
                    SponsorBid.last_message_at.isnot(None),
                ),
            ),
        )
        .order_by(SponsorBid.last_message_at.desc().nullslast())
    )
    result = await db.execute(q)
    rows = result.all()

    conversations = []
    for bid, cat, event, sponsor_user, organizer_user in rows:
        is_sponsor = bid.sponsor_user_id == user_id
        unread = bid.unread_count_sponsor if is_sponsor else bid.unread_count_organizer
        conversations.append({
            "bid_id": bid.id,
            "event_id": event.id,
            "event_title": event.title,
            "category_name": cat.name,
            "bid_status": bid.status.value,
            "event_status": event.status.value,
            "sponsor_user_id": bid.sponsor_user_id,
            "organizer_user_id": event.organizer_id,
            "sponsor_name": sponsor_user.display_name or sponsor_user.email,
            "organizer_name": organizer_user.display_name or organizer_user.email,
            "last_message_at": bid.last_message_at.isoformat() if bid.last_message_at else None,
            "unread_count": unread or 0,
            "is_writable": (
                bid.status in OPEN_BID_STATUSES
                and event.status in OPEN_EVENT_STATUSES
            ),
        })
    return conversations


async def archive_stream(bid_id: int) -> bool:
    """Export a bid's chat stream to a gzipped JSON file, then delete from Redis."""
    r = await _get_redis()
    try:
        stream_key = f"{STREAM_PREFIX}{bid_id}"
        cursor_key = f"{READ_CURSOR_PREFIX}{bid_id}"

        raw = await r.xrange(stream_key, "-", "+")
        if not raw:
            await r.delete(stream_key, cursor_key)
            return False

        messages = []
        for msg_id, fields in raw:
            messages.append({"id": msg_id, **fields})

        ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
        date_str = datetime.now(timezone.utc).strftime("%Y%m%d")
        dest = ARCHIVE_DIR / f"bid_{bid_id}_{date_str}.json.gz"
        with gzip.open(dest, "wt", encoding="utf-8") as f:
            json.dump({"bid_id": bid_id, "archived_at": date_str, "messages": messages}, f)

        await r.delete(stream_key, cursor_key)
        logger.info("Archived chat stream bid=%d (%d messages) -> %s", bid_id, len(messages), dest)
        return True
    finally:
        await r.aclose()


async def purge_old_archives(retention_days: int = 30) -> int:
    """Delete archived chat files older than retention_days."""
    if not ARCHIVE_DIR.exists():
        return 0
    cutoff = time.time() - (retention_days * 86400)
    purged = 0
    for f in ARCHIVE_DIR.iterdir():
        if f.is_file() and f.suffix == ".gz" and f.stat().st_mtime < cutoff:
            f.unlink()
            purged += 1
    if purged:
        logger.info("Purged %d old chat archives", purged)
    return purged
