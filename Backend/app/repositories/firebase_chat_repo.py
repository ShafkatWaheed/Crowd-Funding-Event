"""Firebase Realtime Database repository for chat channels, posts, reactions, and DMs.

All Firebase Admin SDK calls are isolated here. Services never touch RTDB directly.
"""
from __future__ import annotations

from typing import Any

from app.core.firebase import get_rtdb_ref
from app.logger import get_logger

logger = get_logger("repo.firebase_chat")

ROOT = "crowd_funding_chat"


class FirebaseChatRepository:
    """Stateless repository — all methods are standalone."""

    def _ref(self, path: str):
        return get_rtdb_ref(f"{ROOT}/{path}")

    # ── Channels ─────────────────────────────────────────────

    def create_channel(self, channel_id: str, data: dict[str, Any]) -> dict:
        self._ref(f"channels/{channel_id}").set(data)
        return data

    def get_channel(self, channel_id: str) -> dict | None:
        return self._ref(f"channels/{channel_id}").get()

    def update_channel_status(self, channel_id: str, status: str) -> None:
        self._ref(f"channels/{channel_id}/status").set(status)

    def add_channel_member(self, channel_id: str, firebase_uid: str) -> None:
        self._ref(f"channel_members/{channel_id}/{firebase_uid}").set(True)

    def remove_channel_member(self, channel_id: str, firebase_uid: str) -> None:
        self._ref(f"channel_members/{channel_id}/{firebase_uid}").delete()

    def get_channel_members(self, channel_id: str) -> list[str]:
        data = self._ref(f"channel_members/{channel_id}").get()
        if not data:
            return []
        return list(data.keys())

    # ── Posts ─────────────────────────────────────────────────

    def create_post(self, channel_id: str, data: dict[str, Any]) -> str:
        ref = self._ref(f"posts/{channel_id}").push(data)
        return ref.key

    def get_posts(
        self, channel_id: str, limit: int = 50, before_key: str | None = None
    ) -> list[dict]:
        ref = self._ref(f"posts/{channel_id}")
        query = ref.order_by_key()
        if before_key:
            query = query.end_at(before_key).limit_to_last(limit + 1)
            result = query.get() or {}
            result.pop(before_key, None)
        else:
            query = query.limit_to_last(limit)
            result = query.get() or {}
        posts = []
        for key, val in result.items():
            val["post_id"] = key
            posts.append(val)
        return posts

    def update_post_image(self, channel_id: str, post_id: str, image_url: str) -> None:
        self._ref(f"posts/{channel_id}/{post_id}/image_url").set(image_url)

    def update_last_post_at(self, channel_id: str, timestamp: int) -> None:
        self._ref(f"channels/{channel_id}/last_post_at").set(timestamp)

    # ── Reactions (sharded counters) ─────────────────────────

    def aggregate_reactions(self, channel_id: str, post_id: str) -> dict[str, int]:
        shards = self._ref(f"reaction_shards/{channel_id}/{post_id}").get() or {}
        totals = {"like": 0, "dislike": 0}
        for shard_data in shards.values():
            if isinstance(shard_data, dict):
                totals["like"] += shard_data.get("like", 0)
                totals["dislike"] += shard_data.get("dislike", 0)
        return totals

    def write_reaction_counts(
        self, channel_id: str, post_id: str, counts: dict[str, int]
    ) -> None:
        self._ref(f"posts/{channel_id}/{post_id}/reaction_counts").set(counts)

    # ── Read cursors ─────────────────────────────────────────

    def get_read_cursor(self, channel_id: str, firebase_uid: str) -> str | None:
        return self._ref(f"channel_read_cursors/{channel_id}/{firebase_uid}").get()

    def set_read_cursor(
        self, channel_id: str, firebase_uid: str, post_id: str
    ) -> None:
        self._ref(f"channel_read_cursors/{channel_id}/{firebase_uid}").set(post_id)

    # ── Conversations (DMs) ──────────────────────────────────

    def create_conversation(self, conv_id: str, data: dict[str, Any]) -> dict:
        self._ref(f"conversations/{conv_id}").set(data)
        return data

    def get_conversation(self, conv_id: str) -> dict | None:
        return self._ref(f"conversations/{conv_id}").get()

    def add_user_conversation(self, firebase_uid: str, conv_id: str) -> None:
        self._ref(f"user_conversations/{firebase_uid}/{conv_id}").set(True)

    def remove_user_conversation(self, firebase_uid: str, conv_id: str) -> None:
        self._ref(f"user_conversations/{firebase_uid}/{conv_id}").delete()

    def update_conversation_status(self, conv_id: str, status: str) -> None:
        self._ref(f"conversations/{conv_id}/status").set(status)

    def update_last_message(
        self, conv_id: str, text: str, timestamp: int
    ) -> None:
        self._ref(f"conversations/{conv_id}").update(
            {"last_message_at": timestamp, "last_message_text": text}
        )

    def increment_unread(self, conv_id: str, user_id: str) -> None:
        ref = self._ref(f"conversations/{conv_id}/unread/{user_id}")
        current = ref.get() or 0
        ref.set(current + 1)

    def update_message_image(
        self, conv_id: str, message_id: str, image_url: str
    ) -> None:
        self._ref(f"messages/{conv_id}/{message_id}/image_url").set(image_url)

    # ── Cleanup ──────────────────────────────────────────────

    def delete_conversation(self, conv_id: str) -> None:
        self._ref(f"conversations/{conv_id}").delete()
        self._ref(f"messages/{conv_id}").delete()

    def delete_channel(self, channel_id: str) -> None:
        self._ref(f"channels/{channel_id}").delete()
        self._ref(f"posts/{channel_id}").delete()
        self._ref(f"reaction_shards/{channel_id}").delete()
        self._ref(f"user_reactions/{channel_id}").delete()
        self._ref(f"channel_members/{channel_id}").delete()
        self._ref(f"channel_read_cursors/{channel_id}").delete()

    def export_messages(self, conv_id: str) -> list[dict]:
        data = self._ref(f"messages/{conv_id}").get() or {}
        return [{"id": k, **v} for k, v in data.items()]

    def export_posts(self, channel_id: str) -> list[dict]:
        data = self._ref(f"posts/{channel_id}").get() or {}
        return [{"id": k, **v} for k, v in data.items()]


firebase_chat_repo = FirebaseChatRepository()
