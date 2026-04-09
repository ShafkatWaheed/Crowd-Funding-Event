"""Persistent Firebase RTDB listener for chat side effects.

Listens to:
- crowd_funding_chat/messages — updates last_message, unread counts, FCM push
- crowd_funding_chat/reaction_shards — aggregates reactions and writes totals

Runs as a standalone process alongside the ARQ worker.
"""
from __future__ import annotations

from app.core.firebase import get_rtdb_ref
from app.logger import get_logger
from app.repositories.firebase_chat_repo import firebase_chat_repo

logger = get_logger("worker.firebase_chat_listener")

# Cache organizer Firebase UIDs per conv_id (they don't change)
_organizer_uid_cache: dict[str, str | None] = {}

ROOT = "crowd_funding_chat"


def start_listener():
    """Start Firebase RTDB listeners. Call once at worker startup."""
    logger.info("Starting Firebase chat listeners")

    messages_ref = get_rtdb_ref(f"{ROOT}/messages")
    messages_ref.listen(_on_message_event)

    shards_ref = get_rtdb_ref(f"{ROOT}/reaction_shards")
    shards_ref.listen(_on_reaction_event)

    logger.info("Firebase chat listeners started")


def _on_message_event(event):
    """Handle new message events from Firebase."""
    if event.event_type != "put" or not event.data:
        return

    path = event.path  # e.g. "/conv_id/push_id"
    parts = path.strip("/").split("/")
    if len(parts) < 2:
        return

    conv_id = parts[0]
    data = event.data

    if not isinstance(data, dict) or "body" not in data:
        return

    try:
        body = data.get("body", "")
        created_at = data.get("created_at", 0)
        sender_id = data.get("sender_id")

        firebase_chat_repo.update_last_message(conv_id, body, created_at)

        # Determine recipient Firebase UID for unread increment.
        # conv_id format: event_{eventId}_user_{customerFirebaseUid}
        # Both participants are in user_conversations/{uid}/{conv_id}
        conv_parts = conv_id.split("_user_")
        customer_uid = conv_parts[1] if len(conv_parts) == 2 else None

        conv_data = firebase_chat_repo.get_conversation(conv_id)
        if conv_data and customer_uid:
            customer_pg_id = conv_data.get("customer_user_id")
            # Find organizer UID: check who else has this conv in user_conversations
            organizer_uid = _resolve_organizer_uid(conv_id, customer_uid)

            if organizer_uid:
                if sender_id == customer_pg_id:
                    firebase_chat_repo.increment_unread(conv_id, organizer_uid)
                else:
                    firebase_chat_repo.increment_unread(conv_id, customer_uid)

        logger.debug("Processed new message", extra={"conv_id": conv_id})
    except Exception:
        logger.exception("Error processing message event", extra={"path": path})


def _on_reaction_event(event):
    """Handle reaction shard changes — aggregate and write totals."""
    if event.event_type != "put" or event.data is None:
        return

    path = event.path  # e.g. "/channel_id/post_id/shard_N"
    parts = path.strip("/").split("/")
    if len(parts) < 3:
        return

    channel_id = parts[0]
    post_id = parts[1]

    try:
        totals = firebase_chat_repo.aggregate_reactions(channel_id, post_id)
        firebase_chat_repo.write_reaction_counts(channel_id, post_id, totals)
        logger.debug(
            "Aggregated reactions",
            extra={"channel_id": channel_id, "post_id": post_id, "totals": totals},
        )
    except Exception:
        logger.exception(
            "Error aggregating reactions",
            extra={"channel_id": channel_id, "post_id": post_id},
        )


def _resolve_organizer_uid(conv_id: str, customer_uid: str) -> str | None:
    """Find the organizer's Firebase UID for a conversation.

    Looks at the user_conversations index to find who else (besides the
    customer) has this conversation. Caches the result.
    """
    if conv_id in _organizer_uid_cache:
        return _organizer_uid_cache[conv_id]

    try:
        # Scan user_conversations to find the other participant
        # This is expensive but only done once per conv_id (cached)
        ref = get_rtdb_ref(f"{ROOT}/user_conversations")
        all_users = ref.get() or {}
        for uid, convs in all_users.items():
            if uid != customer_uid and isinstance(convs, dict) and conv_id in convs:
                _organizer_uid_cache[conv_id] = uid
                return uid
    except Exception:
        logger.debug("Could not resolve organizer UID for %s", conv_id)

    _organizer_uid_cache[conv_id] = None
    return None
