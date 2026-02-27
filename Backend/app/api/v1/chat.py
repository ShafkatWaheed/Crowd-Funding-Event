"""
Sponsor-organizer negotiation chat: WebSocket endpoint + REST history.

WebSocket at /ws/chat handles real-time messaging via a JSON protocol.
REST endpoints provide message history, conversations list, and mark-read.
Messages are stored in Redis Streams; only metadata touches PostgreSQL.
"""
from __future__ import annotations

import asyncio
import json
import uuid
from typing import Any

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.firebase import verify_id_token
from app.db.base import async_session_maker, get_db_session, get_read_db_session
from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.logger import get_logger
from app.models.notification import NotificationType
from app.models.user import User
from app.services import chat_service
from app.services import notification_service as notif_svc
from app.services import platform_settings as settings_svc

logger = get_logger("chat.ws")

router = APIRouter()

# In-memory registry of connected WebSocket users (local process only).
# Multi-process deployments rely on Redis Pub/Sub for cross-process routing.
_connections: dict[int, WebSocket] = {}

HEARTBEAT_INTERVAL = 30


# ── WebSocket endpoint ──────────────────────────────────────────────────────


async def _authenticate_ws(token: str) -> User | None:
    """Verify Firebase JWT and load user from DB."""
    try:
        decoded = verify_id_token(token)
        uid = decoded.get("uid")
        if not uid:
            return None
    except (ValueError, Exception):
        return None

    from sqlalchemy import select

    async with async_session_maker() as db:
        result = await db.execute(select(User).where(User.firebase_uid == uid))
        return result.scalar_one_or_none()


@router.websocket("/ws/chat")
async def ws_chat(ws: WebSocket, token: str = Query(...)):
    user = await _authenticate_ws(token)
    if not user:
        await ws.close(code=4001, reason="Authentication failed")
        return

    await ws.accept()
    _connections[user.id] = ws
    logger.info("WS connected user=%d", user.id)

    pubsub: aioredis.client.PubSub | None = None
    r: aioredis.Redis | None = None
    joined_bids: set[int] = set()
    pubsub_task: asyncio.Task | None = None

    try:
        r = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
        pubsub = r.pubsub()

        async def _listen_pubsub():
            """Forward Pub/Sub messages to this WebSocket."""
            try:
                async for raw_msg in pubsub.listen():
                    if raw_msg["type"] != "message":
                        continue
                    try:
                        data = json.loads(raw_msg["data"])
                        msg = data.get("message", {})
                        if msg.get("sender_id") != user.id:
                            await ws.send_json(data)
                    except Exception:
                        pass
            except asyncio.CancelledError:
                pass

        pubsub_task = asyncio.create_task(_listen_pubsub())

        while True:
            try:
                raw = await asyncio.wait_for(ws.receive_text(), timeout=HEARTBEAT_INTERVAL)
            except asyncio.TimeoutError:
                try:
                    await ws.send_json({"type": "ping"})
                except Exception:
                    break
                continue

            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                await ws.send_json({"type": "error", "detail": "Invalid JSON"})
                continue

            msg_type = data.get("type")

            if msg_type == "pong":
                continue

            elif msg_type == "join":
                bid_id = data.get("bid_id")
                if not bid_id:
                    await ws.send_json({"type": "error", "detail": "bid_id required"})
                    continue
                try:
                    async with async_session_maker() as db:
                        ctx = await chat_service.validate_participant(db, bid_id, user.id)
                    await pubsub.subscribe(f"chat:bid:{bid_id}")
                    joined_bids.add(bid_id)
                    await ws.send_json({
                        "type": "joined",
                        "bid_id": bid_id,
                        "is_writable": ctx["is_writable"],
                    })
                except ValueError as e:
                    await ws.send_json({"type": "error", "detail": str(e)})

            elif msg_type == "leave":
                bid_id = data.get("bid_id")
                if bid_id and bid_id in joined_bids:
                    await pubsub.unsubscribe(f"chat:bid:{bid_id}")
                    joined_bids.discard(bid_id)

            elif msg_type == "send":
                bid_id = data.get("bid_id")
                body = data.get("body", "").strip()
                client_id = data.get("client_id", uuid.uuid4().hex)

                if not bid_id or bid_id not in joined_bids:
                    await ws.send_json({"type": "error", "detail": "Join the bid channel first"})
                    continue

                async with async_session_maker() as db:
                    max_len = await settings_svc.get_int(db, "chat_max_message_length")

                if not body:
                    await ws.send_json({"type": "error", "detail": "Empty message"})
                    continue
                if len(body) > max_len:
                    await ws.send_json({"type": "error", "detail": f"Message exceeds {max_len} chars"})
                    continue

                try:
                    async with async_session_maker() as db:
                        ctx = await chat_service.validate_participant(db, bid_id, user.id)
                        if not ctx["is_writable"]:
                            await ws.send_json({"type": "error", "detail": "Chat is read-only"})
                            continue

                        msg = await chat_service.send_message(bid_id, user.id, body, client_id)
                        await chat_service.update_pg_metadata(db, bid_id, ctx["is_sponsor"])
                        await db.commit()

                        await ws.send_json({
                            "type": "sent",
                            "client_id": client_id,
                            "message_id": msg["id"],
                            "created_at": msg["created_at"],
                        })

                        recipient_id = (
                            ctx["organizer_user_id"]
                            if ctx["is_sponsor"]
                            else ctx["sponsor_user_id"]
                        )
                        if recipient_id not in _connections:
                            await _send_offline_push(db, recipient_id, user, body, bid_id)
                            await db.commit()

                except ValueError as e:
                    await ws.send_json({"type": "error", "detail": str(e)})

            elif msg_type == "ack":
                message_id = data.get("message_id")
                bid_id = data.get("bid_id")
                if message_id and bid_id:
                    payload = json.dumps({
                        "type": "delivered",
                        "message_id": message_id,
                        "by": user.id,
                    })
                    try:
                        r2 = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
                        await r2.publish(f"chat:bid:{bid_id}", payload)
                        await r2.aclose()
                    except Exception:
                        pass

            elif msg_type == "read":
                bid_id = data.get("bid_id")
                message_id = data.get("message_id")
                if bid_id and message_id:
                    await chat_service.mark_read(bid_id, user.id, message_id)
                    async with async_session_maker() as db:
                        try:
                            ctx = await chat_service.validate_participant(db, bid_id, user.id)
                            await chat_service.clear_unread(db, bid_id, ctx["is_sponsor"])
                            await db.commit()
                        except ValueError:
                            pass

                    payload = json.dumps({
                        "type": "read",
                        "message_id": message_id,
                        "bid_id": bid_id,
                        "by": user.id,
                    })
                    try:
                        r2 = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
                        await r2.publish(f"chat:bid:{bid_id}", payload)
                        await r2.aclose()
                    except Exception:
                        pass

            elif msg_type == "typing":
                bid_id = data.get("bid_id")
                is_typing = data.get("is_typing", False)
                if bid_id and bid_id in joined_bids:
                    payload = json.dumps({
                        "type": "typing",
                        "bid_id": bid_id,
                        "user_id": user.id,
                        "is_typing": is_typing,
                    })
                    try:
                        r2 = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
                        await r2.publish(f"chat:bid:{bid_id}", payload)
                        await r2.aclose()
                    except Exception:
                        pass

    except WebSocketDisconnect:
        logger.info("WS disconnected user=%d", user.id)
    except Exception:
        logger.exception("WS error user=%d", user.id)
    finally:
        _connections.pop(user.id, None)
        if pubsub_task:
            pubsub_task.cancel()
        if pubsub:
            for bid_id in joined_bids:
                try:
                    await pubsub.unsubscribe(f"chat:bid:{bid_id}")
                except Exception:
                    pass
            await pubsub.aclose()
        if r:
            await r.aclose()


async def _send_offline_push(
    db: AsyncSession,
    recipient_id: int,
    sender: User,
    body: str,
    bid_id: int,
) -> None:
    """Send FCM push notification to the offline recipient."""
    sender_name = sender.display_name or sender.email
    await notif_svc.create_notification(
        db,
        user_id=recipient_id,
        type=NotificationType.chat_message,
        title=f"New message from {sender_name}",
        message=body[:100],
        data={"bid_id": bid_id, "route": f"/chat/bid/{bid_id}"},
    )


# ── REST endpoints ───────────────────────────────────────────────────────────


@router.get("/bids/{bid_id}/messages")
async def get_chat_messages(
    bid_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
    before: str | None = Query(None, description="Redis Stream ID to paginate before"),
    limit: int = Query(50, ge=1, le=100),
):
    """Get paginated message history for a bid chat."""
    try:
        await chat_service.validate_participant(db, bid_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))

    messages = await chat_service.get_messages(bid_id, before_id=before, limit=limit)
    return messages


@router.get("/conversations")
async def get_conversations(
    db: ReadDbSession,
    current_user: CurrentUser,
):
    """List bid conversations with unread counts for the current user."""
    return await chat_service.get_conversations(db, current_user.id)


@router.post("/bids/{bid_id}/read")
async def mark_chat_read(
    bid_id: int,
    db: DbSession,
    current_user: CurrentUser,
    message_id: str = Query(..., description="Last read Redis Stream message ID"),
):
    """REST fallback for marking messages as read (when WS is not connected)."""
    try:
        ctx = await chat_service.validate_participant(db, bid_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))

    await chat_service.mark_read(bid_id, current_user.id, message_id)
    await chat_service.clear_unread(db, bid_id, ctx["is_sponsor"])
    await db.commit()
    return {"status": "ok"}
