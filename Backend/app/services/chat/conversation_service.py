"""Business logic for 1:1 DM conversations."""
from __future__ import annotations

import time

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.chat import ChatConversation
from app.repositories.chat_repo import chat_conversation_repo
from app.repositories.firebase_chat_repo import firebase_chat_repo

logger = get_logger("svc.chat.conversation")


async def initiate_conversation(
    db: AsyncSession,
    *,
    user_id: int,
    event_id: int,
) -> ChatConversation:
    """Initiate a DM conversation between a user and the event organizer.

    Access gate: user must have a ticket/pledge (customer) or active bid (sponsor).
    Idempotent — returns existing conversation if one exists.
    """
    log_step(logger, "Initiate conversation", event_id=event_id, user_id=user_id)

    from app.services import event as event_svc

    event = await event_svc.get_or_404(db, event_id)

    conv_type = await _determine_conv_type(db, user_id, event_id)
    if not conv_type:
        raise HTTPException(
            status_code=403,
            detail="You need a ticket, pledge, or active sponsor bid to message the organizer",
        )

    existing = await chat_conversation_repo.get_by_event_and_user(db, event_id, user_id)
    if existing:
        return existing

    from app.repositories.user_repo import user_repo

    user = await user_repo.get_by_id(db, user_id)
    organizer = await user_repo.get_by_id(db, event.organizer_id)

    if not user or not user.firebase_uid:
        raise HTTPException(status_code=400, detail="User has no Firebase account")

    conv_id = f"event_{event_id}_user_{user.firebase_uid}"
    now_ms = int(time.time() * 1000)

    firebase_chat_repo.create_conversation(conv_id, {
        "event_id": event_id,
        "customer_user_id": user_id,
        "organizer_user_id": event.organizer_id,
        "customer_name": user.display_name or user.email or "User",
        "organizer_name": organizer.display_name or organizer.email or "Organizer" if organizer else "Organizer",
        "event_title": event.title,
        "type": conv_type,
        "bid_id": None,
        "status": "open",
        "created_at": now_ms,
        "last_message_at": None,
        "last_message_text": None,
        "unread": {},
    })

    firebase_chat_repo.add_user_conversation(user.firebase_uid, conv_id)
    if organizer and organizer.firebase_uid:
        firebase_chat_repo.add_user_conversation(organizer.firebase_uid, conv_id)

    conv = ChatConversation(
        conversation_id=conv_id,
        event_id=event_id,
        participant_user_id=user_id,
        organizer_user_id=event.organizer_id,
        type=conv_type,
        status="open",
    )
    conv = await chat_conversation_repo.create_conversation(db, conv)

    logger.info("Conversation created", extra={"conv_id": conv_id})
    return conv


async def revoke_access(
    db: AsyncSession,
    *,
    user_id: int,
    event_id: int,
) -> None:
    """Revoke chat access for a user on an event.

    Called on full refund or bid rejection/cancellation.
    Checks remaining financial ties before revoking.
    Sets DM to read-only and removes from announcement channel.
    """
    log_step(logger, "Revoke access", event_id=event_id, user_id=user_id)

    has_remaining = await _has_financial_tie(db, user_id, event_id)
    if has_remaining:
        logger.info(
            "User still has ties, keeping access",
            extra={"user_id": user_id, "event_id": event_id},
        )
        return

    conv = await chat_conversation_repo.get_by_event_and_user(db, event_id, user_id)
    if conv and conv.status == "open":
        await chat_conversation_repo.update_status(db, conv.conversation_id, "read_only")
        firebase_chat_repo.update_conversation_status(conv.conversation_id, "read_only")
        logger.info("DM set to read-only", extra={"conv_id": conv.conversation_id})

    channel_type = "sponsor" if conv and conv.type == "sponsor" else "customer"
    from app.services.chat import channel_service

    await channel_service.remove_member(
        db, event_id=event_id, user_id=user_id, channel_type=channel_type
    )

    logger.info("Access revoked", extra={"user_id": user_id, "event_id": event_id})


async def close_event_conversations(
    db: AsyncSession,
    *,
    event_id: int,
) -> None:
    """Mark all conversations for an event as read_only."""
    convs = await chat_conversation_repo.list_open_by_event(db, event_id)
    for conv in convs:
        await chat_conversation_repo.update_status(db, conv.conversation_id, "read_only")
        firebase_chat_repo.update_conversation_status(conv.conversation_id, "read_only")
    logger.info(
        "Closed conversations for event",
        extra={"event_id": event_id, "count": len(convs)},
    )


async def get_conversations_for_user(
    db: AsyncSession,
    *,
    user_id: int,
) -> list[dict]:
    """List conversations for a user, enriched with Firebase metadata."""
    from app.repositories.user_repo import user_repo

    user = await user_repo.get_by_id(db, user_id)
    firebase_uid = user.firebase_uid if user else str(user_id)

    convs = await chat_conversation_repo.list_by_user(db, user_id)
    result = []
    for conv in convs:
        fb_data = firebase_chat_repo.get_conversation(conv.conversation_id)
        result.append({
            "conversation_id": conv.conversation_id,
            "event_id": conv.event_id,
            "event_title": conv.event.title if conv.event else None,
            "participant_user_id": conv.participant_user_id,
            "organizer_user_id": conv.organizer_user_id,
            "type": conv.type,
            "status": conv.status,
            "last_message_text": fb_data.get("last_message_text") if fb_data else None,
            "last_message_at": fb_data.get("last_message_at") if fb_data else None,
            "unread_count": (
                fb_data.get("unread", {}).get(firebase_uid, 0)
            ) if fb_data else 0,
        })
    return result


async def get_conversations_for_event(
    db: AsyncSession,
    *,
    event_id: int,
    organizer_id: int,
    type_filter: str | None = None,
) -> list[dict]:
    """List conversations for an event (organizer inbox)."""
    from app.services import event as event_svc

    event = await event_svc.get_or_404(db, event_id)
    from app.services.chat.channel_service import _is_organizer_or_co

    if not await _is_organizer_or_co(db, event, organizer_id):
        raise HTTPException(status_code=403, detail="Not an organizer for this event")

    from app.repositories.user_repo import user_repo

    organizer = await user_repo.get_by_id(db, organizer_id)
    org_firebase_uid = organizer.firebase_uid if organizer else str(organizer_id)

    convs = await chat_conversation_repo.list_by_event(db, event_id, type_filter)
    result = []
    for conv in convs:
        fb_data = firebase_chat_repo.get_conversation(conv.conversation_id)
        participant = await user_repo.get_by_id(db, conv.participant_user_id)
        result.append({
            "conversation_id": conv.conversation_id,
            "event_id": conv.event_id,
            "participant_user_id": conv.participant_user_id,
            "participant_name": participant.display_name if participant else None,
            "organizer_user_id": conv.organizer_user_id,
            "type": conv.type,
            "status": conv.status,
            "last_message_text": fb_data.get("last_message_text") if fb_data else None,
            "last_message_at": fb_data.get("last_message_at") if fb_data else None,
            "unread_count": (
                fb_data.get("unread", {}).get(org_firebase_uid, 0)
            ) if fb_data else 0,
        })
    return result


# ── Helpers ──────────────────────────────────────────────────


async def _determine_conv_type(
    db: AsyncSession, user_id: int, event_id: int
) -> str | None:
    """Determine if user qualifies for customer or sponsor DM."""
    from app.repositories.funding_repo import funding_repo
    from app.repositories.ticket_repo import ticket_repo

    has_pledge = await funding_repo.has_active_pledges(db, event_id, user_id)
    has_ticket = await ticket_repo.has_active_ticket_sales(db, event_id, user_id)
    if has_pledge or has_ticket:
        return "customer"

    from app.repositories.sponsor_repo import sponsor_repo

    has_bid = await sponsor_repo.has_active_bid(db, event_id, user_id)
    if has_bid:
        return "sponsor"

    return None


async def _has_financial_tie(
    db: AsyncSession, user_id: int, event_id: int
) -> bool:
    """Check if user has any remaining financial tie to the event."""
    from app.repositories.funding_repo import funding_repo
    from app.repositories.ticket_repo import ticket_repo
    from app.repositories.sponsor_repo import sponsor_repo

    has_pledge = await funding_repo.has_active_pledges(db, event_id, user_id)
    has_ticket = await ticket_repo.has_active_ticket_sales(db, event_id, user_id)
    has_bid = await sponsor_repo.has_active_bid(db, event_id, user_id)
    return has_pledge or has_ticket or has_bid
