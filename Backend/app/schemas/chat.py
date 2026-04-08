"""Pydantic schemas for chat API requests and responses."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


# ── Channel schemas ──────────────────────────────────────────


class ChannelCreateRequest(BaseModel):
    event_id: int
    channel_type: str = Field(pattern=r"^(customer|sponsor)$")


class PostCreateRequest(BaseModel):
    body: str = Field(min_length=1, max_length=2000)
    msg_type: str = Field(default="text", pattern=r"^(text|image)$")


class ChannelResponse(BaseModel):
    id: int
    channel_id: str
    event_id: int
    organizer_user_id: int
    type: str
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class PostResponse(BaseModel):
    post_id: str
    channel_id: str
    sender_id: int
    body: str
    msg_type: str
    image_url: str | None = None
    created_at: int
    reaction_counts: dict[str, int] = Field(
        default_factory=lambda: {"like": 0, "dislike": 0}
    )


# ── Conversation schemas ─────────────────────────────────────


class ConversationCreateRequest(BaseModel):
    event_id: int


class ConversationResponse(BaseModel):
    id: int
    conversation_id: str
    event_id: int
    participant_user_id: int
    organizer_user_id: int
    type: str
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ConversationListItem(BaseModel):
    conversation_id: str
    event_id: int
    event_title: str | None = None
    participant_user_id: int
    participant_name: str | None = None
    organizer_user_id: int
    organizer_name: str | None = None
    type: str
    status: str
    last_message_text: str | None = None
    last_message_at: int | None = None
    unread_count: int = 0
