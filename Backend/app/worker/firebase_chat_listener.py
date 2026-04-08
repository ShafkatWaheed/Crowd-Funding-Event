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
        sender_id = str(data.get("sender_id", ""))

        firebase_chat_repo.update_last_message(conv_id, body, created_at)

        conv_data = firebase_chat_repo.get_conversation(conv_id)
        if conv_data:
            customer_id = str(conv_data.get("customer_user_id", ""))
            organizer_id = str(conv_data.get("organizer_user_id", ""))
            recipient_id = organizer_id if sender_id == customer_id else customer_id
            firebase_chat_repo.increment_unread(conv_id, recipient_id)

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
