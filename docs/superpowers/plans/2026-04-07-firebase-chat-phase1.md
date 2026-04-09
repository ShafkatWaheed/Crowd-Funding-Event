# Firebase RTDB Chat — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build announcement channels + customer DMs on Firebase RTDB, with a unified "My Events" tab and organizer inbox (customer section only).

**Architecture:** Firebase RTDB for real-time messaging and reactions. Backend acts as gatekeeper (validates access, creates channels/conversations) and listener (aggregates reactions, sends FCM). Frontend reads/writes Firebase directly for messages and reactions; REST for gated operations. PostgreSQL tracks channel/conversation lifecycle.

**Tech Stack:** Firebase Admin SDK (Python), firebase_database (Flutter), SQLAlchemy, FastAPI, Alembic, Provider, GoRouter

**Spec:** `docs/superpowers/specs/2026-04-07-firebase-rtdb-chat-design-v2.md`

---

## File Map

### Backend — New Files
| File | Responsibility |
|------|---------------|
| `Backend/alembic/versions/zz16_chat_tables.py` | Migration: `chat_channel` + `chat_conversation` tables |
| `Backend/app/models/chat.py` | SQLAlchemy models: `ChatChannel`, `ChatConversation` |
| `Backend/app/schemas/chat.py` | Pydantic request/response schemas |
| `Backend/app/repositories/firebase_chat_repo.py` | All Firebase Admin SDK calls (channels, posts, reactions, DMs) |
| `Backend/app/repositories/chat_repo.py` | PostgreSQL queries for `chat_channel` + `chat_conversation` |
| `Backend/app/services/chat/__init__.py` | Package init |
| `Backend/app/services/chat/channel_service.py` | Announcement channel business logic |
| `Backend/app/services/chat/conversation_service.py` | DM business logic |
| `Backend/app/api/v1/chat_channels.py` | Announcement channel routes |
| `Backend/app/api/v1/chat_conversations.py` | DM routes |
| `Backend/app/worker/firebase_chat_listener.py` | Persistent listener for messages + reaction shards |
| `Backend/tests/test_chat_channel_service.py` | Channel service tests |
| `Backend/tests/test_chat_conversation_service.py` | Conversation service tests |
| `Backend/tests/test_chat_routes.py` | Route integration tests |

### Backend — Modified Files
| File | Change |
|------|--------|
| `Backend/app/api/v1/router.py` | Register `chat_channels` and `chat_conversations` routers |
| `Backend/app/core/firebase.py` | Add `get_rtdb_ref()` helper for Realtime Database |
| `Backend/app/services/platform_settings.py` | Add `completed_event_chat_retention_days` default |
| `Backend/app/api/v1/config.py` | Expose new setting in public config |

### Frontend — New Files
| File | Responsibility |
|------|---------------|
| `FrontEnd/lib/models/chat.dart` | ChatChannel, ChatPost, ChatConversation, ChatMessage, MyEventCard models |
| `FrontEnd/lib/repositories/chat_firebase_repository.dart` | Firebase RTDB + REST calls |
| `FrontEnd/lib/providers/chat_firebase_provider.dart` | State management for channels, DMs, My Events |
| `FrontEnd/lib/screens/chat/my_events_tab.dart` | Unified event cards tab |
| `FrontEnd/lib/screens/chat/announcement_channel_screen.dart` | Read announcements + like/dislike |
| `FrontEnd/lib/screens/chat/dm_chat_screen.dart` | 1:1 DM screen |
| `FrontEnd/lib/screens/chat/organizer_inbox_screen.dart` | Organizer event list |
| `FrontEnd/lib/screens/chat/organizer_event_chat_hub.dart` | Customer section: announcements + DMs |

### Frontend — Modified Files
| File | Change |
|------|--------|
| `FrontEnd/pubspec.yaml` | Add `firebase_database` dependency |
| `FrontEnd/lib/main.dart` | Register ChatFirebaseProvider + ChatFirebaseRepository |
| `FrontEnd/lib/config/router.dart` | Add routes for announcement, DM, organizer inbox screens |
| `FrontEnd/lib/screens/home/home_screen.dart` | Replace Tickets/Channel tab with My Events tab for customers |
| `FrontEnd/lib/models/event.dart` | Add `completedEventChatRetentionDays` to PublicConfig |
| `FrontEnd/lib/providers/config_provider.dart` | Add `completedEventChatRetentionDays` field |

---

## Task 1: Alembic Migration — Chat Tables

**Files:**
- Create: `Backend/alembic/versions/zz16_chat_tables.py`

- [ ] **Step 1: Create the migration file**

```python
"""Add chat_channel and chat_conversation tables.

Revision ID: zz16_chat_tables
Revises: zz15_ticket_attendee_name
Create Date: 2026-04-07
"""
import sqlalchemy as sa
from alembic import op

revision = "zz16_chat_tables"
down_revision = "zz15_ticket_attendee_name"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_channels",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("channel_id", sa.String(100), unique=True, nullable=False),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False),
        sa.Column("organizer_user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("event_id", "type", name="uq_chat_channel_event_type"),
    )
    op.create_index("ix_chat_channels_event_id", "chat_channels", ["event_id"])

    op.create_table(
        "chat_conversations",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("conversation_id", sa.String(150), unique=True, nullable=False),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False),
        sa.Column("participant_user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("organizer_user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("event_id", "participant_user_id", name="uq_chat_conv_event_participant"),
    )
    op.create_index("ix_chat_conversations_event_id", "chat_conversations", ["event_id"])
    op.create_index("ix_chat_conversations_participant", "chat_conversations", ["participant_user_id"])


def downgrade() -> None:
    op.drop_table("chat_conversations")
    op.drop_table("chat_channels")
```

- [ ] **Step 2: Run the migration**

Run: `cd Backend && alembic upgrade head`
Expected: Tables `chat_channels` and `chat_conversations` created successfully.

- [ ] **Step 3: Verify tables exist**

Run: `cd Backend && python -c "from sqlalchemy import inspect, create_engine; e = create_engine('postgresql://shafkat:shafkat@localhost:5432/crowd_funding'); i = inspect(e); print('chat_channels' in i.get_table_names(), 'chat_conversations' in i.get_table_names())"`
Expected: `True True`

- [ ] **Step 4: Commit**

```bash
git add Backend/alembic/versions/zz16_chat_tables.py
git commit -m "feat: add chat_channel and chat_conversation tables"
```

---

## Task 2: SQLAlchemy Models + Pydantic Schemas

**Files:**
- Create: `Backend/app/models/chat.py`
- Create: `Backend/app/schemas/chat.py`

- [ ] **Step 1: Create SQLAlchemy models**

```python
# Backend/app/models/chat.py
"""SQLAlchemy models for chat channels and conversations."""
from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ChatChannelStatus(str, enum.Enum):
    open = "open"
    read_only = "read_only"
    archived = "archived"


class ChatChannelType(str, enum.Enum):
    customer = "customer"
    sponsor = "sponsor"


class ChatChannel(Base):
    __tablename__ = "chat_channels"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    channel_id: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    organizer_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="open")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event")
    organizer = relationship("User", foreign_keys=[organizer_user_id])

    __table_args__ = (
        UniqueConstraint("event_id", "type", name="uq_chat_channel_event_type"),
    )


class ChatConversation(Base):
    __tablename__ = "chat_conversations"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    conversation_id: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    participant_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    organizer_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="open")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    event = relationship("Event")
    participant = relationship("User", foreign_keys=[participant_user_id])
    organizer = relationship("User", foreign_keys=[organizer_user_id])

    __table_args__ = (
        UniqueConstraint("event_id", "participant_user_id", name="uq_chat_conv_event_participant"),
    )
```

- [ ] **Step 2: Create Pydantic schemas**

```python
# Backend/app/schemas/chat.py
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
    reaction_counts: dict[str, int] = Field(default_factory=lambda: {"like": 0, "dislike": 0})


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
```

- [ ] **Step 3: Run tests to verify models load**

Run: `cd Backend && python -c "from app.models.chat import ChatChannel, ChatConversation; from app.schemas.chat import ChannelCreateRequest, ConversationCreateRequest; print('OK')"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add Backend/app/models/chat.py Backend/app/schemas/chat.py
git commit -m "feat: add ChatChannel/ChatConversation models and schemas"
```

---

## Task 3: Firebase RTDB Helper + Repository

**Files:**
- Modify: `Backend/app/core/firebase.py`
- Create: `Backend/app/repositories/firebase_chat_repo.py`

- [ ] **Step 1: Add RTDB helper to firebase.py**

Add this function at the end of `Backend/app/core/firebase.py`:

```python
def get_rtdb_ref(path: str = "/"):
    """Return a Firebase RTDB reference at the given path.
    Requires firebase-admin with RTDB support."""
    from firebase_admin import db as rtdb
    app = get_firebase_app()
    database_url = f"https://{settings.FIREBASE_PROJECT_ID.strip()}-default-rtdb.firebaseio.com"
    return rtdb.reference(path, app=app, url=database_url)
```

- [ ] **Step 2: Create firebase_chat_repo.py**

```python
# Backend/app/repositories/firebase_chat_repo.py
"""Firebase Realtime Database repository for chat channels, posts, reactions, and DMs.

All Firebase Admin SDK calls are isolated here. Services never touch RTDB directly.
"""
from __future__ import annotations

import time
from typing import Any

from app.core.firebase import get_rtdb_ref
from app.logger import get_logger

logger = get_logger("repo.firebase_chat")

ROOT = "crowd_funding_chat"


class FirebaseChatRepository:
    """Stateless repository — all methods are standalone."""

    # ── Channels ─────────────────────────────────────────────

    def _ref(self, path: str):
        return get_rtdb_ref(f"{ROOT}/{path}")

    def create_channel(self, channel_id: str, data: dict[str, Any]) -> dict:
        ref = self._ref(f"channels/{channel_id}")
        ref.set(data)
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
```

- [ ] **Step 3: Commit**

```bash
git add Backend/app/core/firebase.py Backend/app/repositories/firebase_chat_repo.py
git commit -m "feat: add Firebase RTDB helper and firebase_chat_repo"
```

---

## Task 4: PostgreSQL Chat Repository

**Files:**
- Create: `Backend/app/repositories/chat_repo.py`

- [ ] **Step 1: Create chat_repo.py**

```python
# Backend/app/repositories/chat_repo.py
"""PostgreSQL repository for chat_channel and chat_conversation lifecycle metadata."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.chat import ChatChannel, ChatConversation
from app.repositories.base import BaseRepository


class ChatChannelRepository(BaseRepository[ChatChannel]):
    model_class = ChatChannel

    async def get_by_channel_id(
        self, db: AsyncSession, channel_id: str
    ) -> ChatChannel | None:
        q = select(ChatChannel).where(ChatChannel.channel_id == channel_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def get_by_event_and_type(
        self, db: AsyncSession, event_id: int, channel_type: str
    ) -> ChatChannel | None:
        q = select(ChatChannel).where(
            ChatChannel.event_id == event_id,
            ChatChannel.type == channel_type,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def list_by_event(
        self, db: AsyncSession, event_id: int
    ) -> list[ChatChannel]:
        q = (
            select(ChatChannel)
            .where(ChatChannel.event_id == event_id)
            .order_by(ChatChannel.type)
        )
        return list((await db.execute(q)).scalars().all())

    async def create_channel(
        self, db: AsyncSession, channel: ChatChannel
    ) -> ChatChannel:
        db.add(channel)
        await db.flush()
        await db.refresh(channel)
        return channel

    async def update_status(
        self, db: AsyncSession, channel_id: str, status: str
    ) -> None:
        ch = await self.get_by_channel_id(db, channel_id)
        if ch:
            ch.status = status
            await db.flush()


class ChatConversationRepository(BaseRepository[ChatConversation]):
    model_class = ChatConversation

    async def get_by_conv_id(
        self, db: AsyncSession, conv_id: str
    ) -> ChatConversation | None:
        q = select(ChatConversation).where(
            ChatConversation.conversation_id == conv_id
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def get_by_event_and_user(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> ChatConversation | None:
        q = select(ChatConversation).where(
            ChatConversation.event_id == event_id,
            ChatConversation.participant_user_id == user_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def list_by_event(
        self, db: AsyncSession, event_id: int, type_filter: str | None = None
    ) -> list[ChatConversation]:
        q = select(ChatConversation).where(
            ChatConversation.event_id == event_id
        )
        if type_filter:
            q = q.where(ChatConversation.type == type_filter)
        q = q.order_by(ChatConversation.created_at.desc())
        return list((await db.execute(q)).scalars().all())

    async def list_by_user(
        self, db: AsyncSession, user_id: int
    ) -> list[ChatConversation]:
        q = (
            select(ChatConversation)
            .options(selectinload(ChatConversation.event))
            .where(ChatConversation.participant_user_id == user_id)
            .order_by(ChatConversation.created_at.desc())
        )
        return list((await db.execute(q)).scalars().all())

    async def list_by_organizer(
        self, db: AsyncSession, organizer_id: int
    ) -> list[ChatConversation]:
        q = (
            select(ChatConversation)
            .options(
                selectinload(ChatConversation.event),
                selectinload(ChatConversation.participant),
            )
            .where(ChatConversation.organizer_user_id == organizer_id)
            .order_by(ChatConversation.created_at.desc())
        )
        return list((await db.execute(q)).scalars().all())

    async def create_conversation(
        self, db: AsyncSession, conv: ChatConversation
    ) -> ChatConversation:
        db.add(conv)
        await db.flush()
        await db.refresh(conv)
        return conv

    async def update_status(
        self, db: AsyncSession, conv_id: str, status: str
    ) -> None:
        conv = await self.get_by_conv_id(db, conv_id)
        if conv:
            conv.status = status
            await db.flush()

    async def list_open_by_event(
        self, db: AsyncSession, event_id: int
    ) -> list[ChatConversation]:
        q = select(ChatConversation).where(
            ChatConversation.event_id == event_id,
            ChatConversation.status == "open",
        )
        return list((await db.execute(q)).scalars().all())


chat_channel_repo = ChatChannelRepository()
chat_conversation_repo = ChatConversationRepository()
```

- [ ] **Step 2: Commit**

```bash
git add Backend/app/repositories/chat_repo.py
git commit -m "feat: add PostgreSQL chat_channel and chat_conversation repos"
```

---

## Task 5: Channel Service

**Files:**
- Create: `Backend/app/services/chat/__init__.py`
- Create: `Backend/app/services/chat/channel_service.py`

- [ ] **Step 1: Create package init**

```python
# Backend/app/services/chat/__init__.py
```

- [ ] **Step 2: Create channel_service.py**

```python
# Backend/app/services/chat/channel_service.py
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

    # Verify organizer
    from app.services import event as event_svc

    event = await event_svc.get_or_404(db, event_id)
    if not await _is_organizer_or_co(db, event, organizer_id):
        raise HTTPException(status_code=403, detail="Not an organizer for this event")

    # Idempotent check
    channel_id = f"event_{event_id}_{channel_type}"
    existing = await chat_channel_repo.get_by_channel_id(db, channel_id)
    if existing:
        return existing

    # Create in Firebase
    now_ms = int(time.time() * 1000)
    firebase_chat_repo.create_channel(channel_id, {
        "event_id": event_id,
        "organizer_user_id": organizer_id,
        "type": channel_type,
        "status": "open",
        "created_at": now_ms,
        "last_post_at": None,
    })

    # Store in PG
    channel = ChatChannel(
        channel_id=channel_id,
        event_id=event_id,
        organizer_user_id=organizer_id,
        type=channel_type,
        status="open",
    )
    channel = await chat_channel_repo.create_channel(db, channel)

    # Add organizer + co-organizers as members
    await _add_organizers_as_members(db, event, channel_id)

    # Add eligible audience
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

    # Send FCM push to all members
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
    """Add a user to a channel. Creates the channel if it doesn't exist yet.

    Idempotent — safe to call multiple times.
    """
    channel_id = f"event_{event_id}_{channel_type}"
    channel = await chat_channel_repo.get_by_channel_id(db, channel_id)
    if not channel:
        # Channel doesn't exist yet — nothing to join
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

    co_orgs = await event_repo.get_co_organizer_ids(db, event.id)
    return user_id in co_orgs


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

        pledger_ids = await funding_repo.get_pledger_user_ids(db, event_id)
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
```

- [ ] **Step 3: Commit**

```bash
git add Backend/app/services/chat/__init__.py Backend/app/services/chat/channel_service.py
git commit -m "feat: add channel_service with create/post/member management"
```

---

## Task 6: Conversation Service

**Files:**
- Create: `Backend/app/services/chat/conversation_service.py`

- [ ] **Step 1: Create conversation_service.py**

```python
# Backend/app/services/chat/conversation_service.py
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

    # Determine conversation type based on user's relationship
    conv_type = await _determine_conv_type(db, user_id, event_id)
    if not conv_type:
        raise HTTPException(
            status_code=403,
            detail="You need a ticket, pledge, or active sponsor bid to message the organizer",
        )

    # Idempotent check
    existing = await chat_conversation_repo.get_by_event_and_user(db, event_id, user_id)
    if existing:
        return existing

    # Build conversation
    from app.repositories.user_repo import user_repo

    user = await user_repo.get_by_id(db, user_id)
    organizer = await user_repo.get_by_id(db, event.organizer_id)

    if not user or not user.firebase_uid:
        raise HTTPException(status_code=400, detail="User has no Firebase account")

    conv_id = f"event_{event_id}_user_{user.firebase_uid}"
    now_ms = int(time.time() * 1000)

    # Create in Firebase
    firebase_chat_repo.create_conversation(conv_id, {
        "event_id": event_id,
        "customer_user_id": user_id,
        "organizer_user_id": event.organizer_id,
        "customer_name": user.display_name or user.email or "User",
        "organizer_name": organizer.display_name or organizer.email or "Organizer",
        "event_title": event.title,
        "type": conv_type,
        "bid_id": None,
        "status": "open",
        "created_at": now_ms,
        "last_message_at": None,
        "last_message_text": None,
        "unread": {},
    })

    # Add both participants to user_conversations index
    firebase_chat_repo.add_user_conversation(user.firebase_uid, conv_id)
    if organizer and organizer.firebase_uid:
        firebase_chat_repo.add_user_conversation(organizer.firebase_uid, conv_id)

    # Store in PG
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

    # Check remaining ties
    has_remaining = await _has_financial_tie(db, user_id, event_id)
    if has_remaining:
        logger.info("User still has ties, keeping access", extra={"user_id": user_id, "event_id": event_id})
        return

    # Set DM to read-only
    conv = await chat_conversation_repo.get_by_event_and_user(db, event_id, user_id)
    if conv and conv.status == "open":
        await chat_conversation_repo.update_status(db, conv.conversation_id, "read_only")
        firebase_chat_repo.update_conversation_status(conv.conversation_id, "read_only")
        logger.info("DM set to read-only", extra={"conv_id": conv.conversation_id})

    # Remove from announcement channel
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
    logger.info("Closed conversations for event", extra={"event_id": event_id, "count": len(convs)})


async def get_conversations_for_user(
    db: AsyncSession,
    *,
    user_id: int,
) -> list[dict]:
    """List conversations for a user, enriched with Firebase metadata."""
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
            "unread_count": (fb_data.get("unread", {}).get(str(user_id), 0)) if fb_data else 0,
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

    convs = await chat_conversation_repo.list_by_event(db, event_id, type_filter)
    result = []
    for conv in convs:
        fb_data = firebase_chat_repo.get_conversation(conv.conversation_id)
        from app.repositories.user_repo import user_repo

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
                fb_data.get("unread", {}).get(str(organizer_id), 0)
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

    has_pledge = await funding_repo.has_active_pledge(db, event_id, user_id)
    has_ticket = await ticket_repo.has_active_ticket(db, event_id, user_id)
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

    has_pledge = await funding_repo.has_active_pledge(db, event_id, user_id)
    has_ticket = await ticket_repo.has_active_ticket(db, event_id, user_id)
    has_bid = await sponsor_repo.has_active_bid(db, event_id, user_id)
    return has_pledge or has_ticket or has_bid
```

- [ ] **Step 2: Commit**

```bash
git add Backend/app/services/chat/conversation_service.py
git commit -m "feat: add conversation_service with initiate/revoke/close"
```

---

## Task 7: API Routes

**Files:**
- Create: `Backend/app/api/v1/chat_channels.py`
- Create: `Backend/app/api/v1/chat_conversations.py`
- Modify: `Backend/app/api/v1/router.py`

- [ ] **Step 1: Create chat_channels.py routes**

```python
# Backend/app/api/v1/chat_channels.py
"""Announcement channel routes."""
from __future__ import annotations

import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, UploadFile

from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.logger import get_logger, log_step
from app.schemas.chat import (
    ChannelCreateRequest,
    ChannelResponse,
    PostCreateRequest,
    PostResponse,
)
from app.services.chat import channel_service

logger = get_logger("api.chat_channels")

router = APIRouter()

UPLOAD_DIR = Path("static/uploads/chat")


@router.post("/chat/channels", response_model=ChannelResponse, status_code=201)
async def create_channel(
    body: ChannelCreateRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Create channel", user_id=current_user.id)
    channel = await channel_service.create_channel(
        db,
        organizer_id=current_user.id,
        event_id=body.event_id,
        channel_type=body.channel_type,
    )
    await db.commit()
    return channel


@router.get("/chat/channels/{channel_id}/posts", response_model=list[PostResponse])
async def list_posts(
    channel_id: str,
    db: ReadDbSession,
    current_user: CurrentUser,
    limit: int = 50,
    before: str | None = None,
):
    from app.repositories.firebase_chat_repo import firebase_chat_repo

    posts = firebase_chat_repo.get_posts(channel_id, limit=limit, before_key=before)
    return [
        PostResponse(
            post_id=p["post_id"],
            channel_id=channel_id,
            sender_id=p.get("sender_id", 0),
            body=p.get("body", ""),
            msg_type=p.get("msg_type", "text"),
            image_url=p.get("image_url"),
            created_at=p.get("created_at", 0),
            reaction_counts=p.get("reaction_counts", {"like": 0, "dislike": 0}),
        )
        for p in posts
    ]


@router.post(
    "/chat/channels/{channel_id}/posts",
    response_model=PostResponse,
    status_code=201,
)
async def create_post(
    channel_id: str,
    body: PostCreateRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Create post", channel_id=channel_id, user_id=current_user.id)
    post = await channel_service.create_post(
        db,
        organizer_id=current_user.id,
        channel_id=channel_id,
        body=body.body,
        msg_type=body.msg_type,
    )
    await db.commit()
    return PostResponse(**post)


@router.post("/chat/channels/{channel_id}/posts/{post_id}/upload")
async def upload_post_image(
    channel_id: str,
    post_id: str,
    file: UploadFile,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Upload post image", channel_id=channel_id, post_id=post_id)
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    ext = Path(file.filename or "img.jpg").suffix
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = UPLOAD_DIR / filename
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)
    image_url = f"/static/uploads/chat/{filename}"

    await channel_service.attach_image(
        db,
        organizer_id=current_user.id,
        channel_id=channel_id,
        post_id=post_id,
        image_url=image_url,
    )
    await db.commit()
    return {"image_url": image_url}
```

- [ ] **Step 2: Create chat_conversations.py routes**

```python
# Backend/app/api/v1/chat_conversations.py
"""DM conversation routes."""
from __future__ import annotations

import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, UploadFile

from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.logger import get_logger, log_step
from app.schemas.chat import (
    ConversationCreateRequest,
    ConversationListItem,
    ConversationResponse,
)
from app.services.chat import conversation_service

logger = get_logger("api.chat_conversations")

router = APIRouter()

UPLOAD_DIR = Path("static/uploads/chat")


@router.post(
    "/chat/conversations",
    response_model=ConversationResponse,
    status_code=201,
)
async def initiate_conversation(
    body: ConversationCreateRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Initiate conversation", user_id=current_user.id)
    conv = await conversation_service.initiate_conversation(
        db, user_id=current_user.id, event_id=body.event_id
    )
    await db.commit()
    return conv


@router.get("/chat/conversations", response_model=list[ConversationListItem])
async def list_my_conversations(
    db: ReadDbSession,
    current_user: CurrentUser,
):
    return await conversation_service.get_conversations_for_user(
        db, user_id=current_user.id
    )


@router.get(
    "/chat/conversations/event/{event_id}",
    response_model=list[ConversationListItem],
)
async def list_event_conversations(
    event_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
    type_filter: str | None = None,
):
    return await conversation_service.get_conversations_for_event(
        db,
        event_id=event_id,
        organizer_id=current_user.id,
        type_filter=type_filter,
    )


@router.post("/chat/conversations/{conv_id}/upload")
async def upload_dm_image(
    conv_id: str,
    file: UploadFile,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Upload DM image", conv_id=conv_id)
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    ext = Path(file.filename or "img.jpg").suffix
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = UPLOAD_DIR / filename
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)
    image_url = f"/static/uploads/chat/{filename}"

    from app.repositories.firebase_chat_repo import firebase_chat_repo

    firebase_chat_repo.update_message_image(conv_id, "latest", image_url)
    await db.commit()
    return {"image_url": image_url}


@router.post("/chat/conversations/{conv_id}/close")
async def close_conversation(
    conv_id: str,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Close conversation", conv_id=conv_id)
    from app.repositories.chat_repo import chat_conversation_repo
    from app.repositories.firebase_chat_repo import firebase_chat_repo

    conv = await chat_conversation_repo.get_by_conv_id(db, conv_id)
    if not conv:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="Conversation not found")
    if conv.organizer_user_id != current_user.id:
        from fastapi import HTTPException

        raise HTTPException(status_code=403, detail="Only the organizer can close conversations")

    await chat_conversation_repo.update_status(db, conv_id, "read_only")
    firebase_chat_repo.update_conversation_status(conv_id, "read_only")
    await db.commit()
    return {"status": "read_only"}
```

- [ ] **Step 3: Register routes in router.py**

Add these lines to `Backend/app/api/v1/router.py` after the existing router includes:

```python
from app.api.v1 import chat_channels, chat_conversations

api_router.include_router(chat_channels.router, prefix="", tags=["chat-channels"])
api_router.include_router(chat_conversations.router, prefix="", tags=["chat-conversations"])
```

- [ ] **Step 4: Commit**

```bash
git add Backend/app/api/v1/chat_channels.py Backend/app/api/v1/chat_conversations.py Backend/app/api/v1/router.py
git commit -m "feat: add chat channel and conversation API routes"
```

---

## Task 8: Admin Config — Retention Setting

**Files:**
- Modify: `Backend/app/services/platform_settings.py`
- Modify: `Backend/app/api/v1/config.py`
- Modify: `FrontEnd/lib/models/event.dart`
- Modify: `FrontEnd/lib/providers/config_provider.dart`

- [ ] **Step 1: Add default to platform_settings.py**

Add to the `DEFAULTS` dict in `Backend/app/services/platform_settings.py`:

```python
"completed_event_chat_retention_days": 7,
```

Add to the `DESCRIPTIONS` dict:

```python
"completed_event_chat_retention_days": "Days after event completion before hiding from My Events tab",
```

- [ ] **Step 2: Expose in config.py**

Add `"completed_event_chat_retention_days"` to the `_PUBLIC_INT_KEYS` set in `Backend/app/api/v1/config.py`.

- [ ] **Step 3: Add to PublicConfig model in event.dart**

Add to the `PublicConfig` class in `FrontEnd/lib/models/event.dart`:

```dart
final int completedEventChatRetentionDays;
```

Add to the constructor with default:

```dart
this.completedEventChatRetentionDays = 7,
```

Add to `fromJson`:

```dart
completedEventChatRetentionDays: json['completed_event_chat_retention_days'] as int? ?? 7,
```

- [ ] **Step 4: Add to ConfigProvider**

Add field to `FrontEnd/lib/providers/config_provider.dart`:

```dart
int completedEventChatRetentionDays = 7;
```

Populate in `fetchConfig()`:

```dart
completedEventChatRetentionDays = config.completedEventChatRetentionDays;
```

- [ ] **Step 5: Commit**

```bash
git add Backend/app/services/platform_settings.py Backend/app/api/v1/config.py FrontEnd/lib/models/event.dart FrontEnd/lib/providers/config_provider.dart
git commit -m "feat: add completed_event_chat_retention_days admin setting"
```

---

## Task 9: Firebase Security Rules

**Files:**
- Create: `Backend/firebase-rules.json`

- [ ] **Step 1: Create the rules file**

Create `Backend/firebase-rules.json` with the full security rules from the spec (Section 2). This file is deployed to the Firebase Console.

```json
{
  "rules": {
    "crowd_funding_chat": {
      "channels": {
        "$channel_id": {
          ".read": "root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists()",
          ".write": false
        }
      },
      "posts": {
        "$channel_id": {
          ".read": "root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists()",
          ".write": false
        }
      },
      "reaction_shards": {
        "$channel_id": {
          "$post_id": {
            "$shard": {
              ".read": false,
              ".write": "root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists() && root.child('crowd_funding_chat/channels/' + $channel_id + '/status').val() == 'open'"
            }
          }
        }
      },
      "user_reactions": {
        "$channel_id": {
          "$post_id": {
            "$uid": {
              ".read": "auth.uid == $uid",
              ".write": "auth.uid == $uid && root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists() && root.child('crowd_funding_chat/channels/' + $channel_id + '/status').val() == 'open'"
            }
          }
        }
      },
      "channel_members": {
        "$channel_id": {
          "$uid": {
            ".read": "auth.uid == $uid",
            ".write": false
          }
        }
      },
      "channel_read_cursors": {
        "$channel_id": {
          "$uid": {
            ".read": "auth.uid == $uid",
            ".write": "auth.uid == $uid && root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists()"
          }
        }
      },
      "conversations": {
        "$conv_id": {
          ".read": "root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists()",
          ".write": false,
          "unread": {
            "$uid": {
              ".write": "auth.uid == $uid && root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists()"
            }
          }
        }
      },
      "messages": {
        "$conv_id": {
          ".read": "root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists()",
          ".write": "root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists() && root.child('crowd_funding_chat/conversations/' + $conv_id + '/status').val() == 'open'"
        }
      },
      "user_conversations": {
        "$uid": {
          ".read": "auth.uid == $uid",
          ".write": false
        }
      },
      "typing": {
        "$conv_id": {
          "$uid": {
            ".read": "root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists()",
            ".write": "auth.uid == $uid"
          }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add Backend/firebase-rules.json
git commit -m "feat: add Firebase RTDB security rules for chat"
```

---

## Task 10: Frontend Models

**Files:**
- Create: `FrontEnd/lib/models/chat.dart`

- [ ] **Step 1: Create chat models**

Create `FrontEnd/lib/models/chat.dart` with all models needed for the chat system. This includes `ChatChannel`, `ChatPost`, `ChatConversation`, `ChatMessage`, `MyEventCard`, and request classes.

Key models with `fromJson` factories, matching the Firebase RTDB data structure from the spec. `MyEventCard` is a composite model that combines event metadata, channel, conversation, and tickets for the unified card UI.

This is a large file — the engineer should reference the spec Section 1 (RTDB data structure) and Section 5b (models list) for exact field mappings.

- [ ] **Step 2: Commit**

```bash
git add FrontEnd/lib/models/chat.dart
git commit -m "feat: add frontend chat models"
```

---

## Task 11: Frontend Firebase Repository

**Files:**
- Modify: `FrontEnd/pubspec.yaml`
- Create: `FrontEnd/lib/repositories/chat_firebase_repository.dart`

- [ ] **Step 1: Add firebase_database to pubspec.yaml**

Add to the `dependencies` section of `FrontEnd/pubspec.yaml`:

```yaml
firebase_database: ^11.1.4
```

- [ ] **Step 2: Run flutter pub get**

Run: `cd FrontEnd && flutter pub get`
Expected: Dependencies resolved successfully.

- [ ] **Step 3: Create chat_firebase_repository.dart**

Create `FrontEnd/lib/repositories/chat_firebase_repository.dart` implementing the repository interface from the spec Section 5c. This class handles:

- Firebase RTDB streams (channels, posts, messages, typing, reactions)
- Sharded counter logic for like/dislike (random shard selection, transaction writes)
- REST calls via Dio for gated operations (initConversation, createChannel, createPost, uploadImage, attachImage)
- Read cursor management
- Stream subscription cleanup on dispose

The engineer should reference the spec's sharded counter flow (Section 3) for the exact reaction logic.

- [ ] **Step 4: Commit**

```bash
git add FrontEnd/pubspec.yaml FrontEnd/lib/repositories/chat_firebase_repository.dart
git commit -m "feat: add ChatFirebaseRepository with RTDB + REST"
```

---

## Task 12: Frontend Provider

**Files:**
- Create: `FrontEnd/lib/providers/chat_firebase_provider.dart`
- Modify: `FrontEnd/lib/main.dart`

- [ ] **Step 1: Create chat_firebase_provider.dart**

Create `FrontEnd/lib/providers/chat_firebase_provider.dart` implementing the provider from spec Section 5d. Key state:

- `myEventCards: List<MyEventCard>` — composite cards for My Events tab
- `activePosts / activeMessages / typingUsers` — active channel/conversation state
- `loading / error` — standard loading state

Key methods: `loadMyEvents()`, `openChannel()`, `closeChannel()`, `createPost()`, `reactToPost()`, `openConversation()`, `closeConversation()`, `sendMessage()`, `markRead()`, `setTyping()`, `initConversation()`.

The `loadMyEvents()` method builds `MyEventCard` list by:
1. Fetching user's conversations from REST
2. Fetching user's tickets from TicketRepository
3. Fetching user's channels from Firebase
4. Grouping by event, sorting by event status (live → upcoming → selling → completed)
5. Filtering out completed events past the retention period

- [ ] **Step 2: Register in main.dart**

Add to `MultiProvider` in `FrontEnd/lib/main.dart`:

```dart
Provider<ChatFirebaseRepository>(
  create: (ctx) => ChatFirebaseRepository(ctx.read<Dio>()),
),
ChangeNotifierProvider(
  create: (ctx) => ChatFirebaseProvider(ctx.read<ChatFirebaseRepository>()),
),
```

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/providers/chat_firebase_provider.dart FrontEnd/lib/main.dart
git commit -m "feat: add ChatFirebaseProvider and register in main.dart"
```

---

## Task 13: Frontend Screens — My Events Tab

**Files:**
- Create: `FrontEnd/lib/screens/chat/my_events_tab.dart`
- Modify: `FrontEnd/lib/screens/home/home_screen.dart`

- [ ] **Step 1: Create my_events_tab.dart**

Create `FrontEnd/lib/screens/chat/my_events_tab.dart` — the unified event cards tab that replaces `MyTicketsScreen` for customers and `ConversationsScreen` for sponsors/organizers.

Key features:
- Watches `ChatFirebaseProvider.myEventCards`
- Renders event cards sorted: live → upcoming → selling → completed (dimmed)
- Each card has: header (event name + status badge), announcements row, DM row, tickets row
- Taps navigate to: event detail (header), announcement channel, DM screen, ticket detail
- Pull-to-refresh calls `loadMyEvents()`
- Live events show pulsing red dot
- Unread badges on announcements and DM rows

- [ ] **Step 2: Modify home_screen.dart**

Replace the 4th tab logic in `home_screen.dart`:

Change:
```dart
if (hasChatTab)
  const ConversationsScreen(embedded: true)
else
  const MyTicketsScreen(),
```

To:
```dart
const MyEventsTab(),
```

Update the bottom nav item:
```dart
// Replace the hasChatTab conditional with:
_navItem(3, Icons.event_note_rounded, Icons.event_note_outlined, 'My Events',
    badge: context.watch<ChatFirebaseProvider>().totalUnreadCount),
```

Remove the `hasChatTab` conditional — all users see "My Events" as the 4th tab. Organizers still see "Channel" as well (kept for organizer inbox).

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/screens/chat/my_events_tab.dart FrontEnd/lib/screens/home/home_screen.dart
git commit -m "feat: add My Events tab with unified event cards"
```

---

## Task 14: Frontend Screens — Announcement Channel

**Files:**
- Create: `FrontEnd/lib/screens/chat/announcement_channel_screen.dart`
- Modify: `FrontEnd/lib/config/router.dart`

- [ ] **Step 1: Create announcement_channel_screen.dart**

Create `FrontEnd/lib/screens/chat/announcement_channel_screen.dart`:

- Reads posts from `ChatFirebaseProvider.activePosts` (real-time stream)
- Each post shows: organizer name, body, image (if any), like/dislike buttons with counts
- Like/dislike buttons highlight based on user's current reaction
- Tapping like/dislike calls `ChatFirebaseProvider.reactToPost()` (sharded counter)
- Organizer sees a compose bar at the bottom to create new posts
- Read-only banner shown when channel status is `read_only`
- Opens channel on `initState`, closes on `dispose`

- [ ] **Step 2: Add route**

Add to `FrontEnd/lib/config/router.dart`:

```dart
GoRoute(
  path: '/chat/channel/:channelId',
  pageBuilder: (context, state) {
    final channelId = state.pathParameters['channelId']!;
    final isOrganizer = state.uri.queryParameters['organizer'] == 'true';
    return sharedAxisPage(
      child: AnnouncementChannelScreen(
        channelId: channelId,
        isOrganizer: isOrganizer,
      ),
    );
  },
),
```

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/screens/chat/announcement_channel_screen.dart FrontEnd/lib/config/router.dart
git commit -m "feat: add announcement channel screen with like/dislike"
```

---

## Task 15: Frontend Screens — DM Chat

**Files:**
- Create: `FrontEnd/lib/screens/chat/dm_chat_screen.dart`
- Modify: `FrontEnd/lib/config/router.dart`

- [ ] **Step 1: Create dm_chat_screen.dart**

Create `FrontEnd/lib/screens/chat/dm_chat_screen.dart` — reuses UI patterns from `bid_chat_screen.dart`:

- Message bubbles (sender vs receiver alignment)
- Typing indicator
- Image picker + upload (Option B: send message first, then attach image)
- Read-only banner when conversation status is `read_only`
- Opens conversation on `initState`, closes on `dispose`
- Reads from `ChatFirebaseProvider.activeMessages`
- Sends via `ChatFirebaseProvider.sendMessage()`

- [ ] **Step 2: Add route**

Add to `FrontEnd/lib/config/router.dart`:

```dart
GoRoute(
  path: '/chat/dm/:convId',
  pageBuilder: (context, state) {
    final convId = state.pathParameters['convId']!;
    final name = state.uri.queryParameters['name'];
    final writable = state.uri.queryParameters['writable'] != 'false';
    return sharedAxisPage(
      child: DmChatScreen(
        conversationId: convId,
        participantName: name,
        isWritable: writable,
      ),
    );
  },
),
```

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/screens/chat/dm_chat_screen.dart FrontEnd/lib/config/router.dart
git commit -m "feat: add DM chat screen"
```

---

## Task 16: Frontend Screens — Organizer Inbox

**Files:**
- Create: `FrontEnd/lib/screens/chat/organizer_inbox_screen.dart`
- Create: `FrontEnd/lib/screens/chat/organizer_event_chat_hub.dart`
- Modify: `FrontEnd/lib/config/router.dart`
- Modify: `FrontEnd/lib/screens/home/home_screen.dart`

- [ ] **Step 1: Create organizer_inbox_screen.dart**

Event list for organizers — shows all events they organize with unread counts. Tapping navigates to the event chat hub.

- [ ] **Step 2: Create organizer_event_chat_hub.dart**

Phase 1: Customer section only.
- Announcement channel row (tap → announcement channel screen as organizer)
- Individual customer DM list (tap → DM screen)
- Unread badges per conversation

- [ ] **Step 3: Add routes**

Add to `FrontEnd/lib/config/router.dart`:

```dart
GoRoute(
  path: '/chat/organizer-inbox',
  pageBuilder: (context, state) => sharedAxisPage(
    child: const OrganizerInboxScreen(),
  ),
),
GoRoute(
  path: '/chat/organizer-hub/:eventId',
  pageBuilder: (context, state) {
    final eventId = int.parse(state.pathParameters['eventId']!);
    return sharedAxisPage(
      child: OrganizerEventChatHub(eventId: eventId),
    );
  },
),
```

- [ ] **Step 4: Wire organizer inbox into home_screen.dart**

For organizers, the "Channel" tab (index 3 when `hasChatTab` was true) should now show `OrganizerInboxScreen` instead of `ConversationsScreen`. Since we changed the 4th tab to "My Events" for everyone, the organizer needs a 5th tab or the inbox embedded differently.

The simplest approach: organizers keep 4 tabs (Home, Explore, Manage, My Events) and access the organizer inbox from the "My Events" tab header via an inbox icon, or from the Manage tab. The engineer should decide the exact placement based on the existing organizer dashboard layout.

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/screens/chat/organizer_inbox_screen.dart FrontEnd/lib/screens/chat/organizer_event_chat_hub.dart FrontEnd/lib/config/router.dart FrontEnd/lib/screens/home/home_screen.dart
git commit -m "feat: add organizer inbox and event chat hub screens"
```

---

## Task 17: Firebase Chat Listener (Worker)

**Files:**
- Create: `Backend/app/worker/firebase_chat_listener.py`

- [ ] **Step 1: Create the listener**

```python
# Backend/app/worker/firebase_chat_listener.py
"""Persistent Firebase RTDB listener for chat side effects.

Listens to:
- crowd_funding_chat/messages — updates last_message, unread counts, FCM push
- crowd_funding_chat/reaction_shards — aggregates reactions and writes totals

Runs as a standalone process alongside the ARQ worker.
"""
from __future__ import annotations

import asyncio
import re

from app.core.firebase import get_rtdb_ref
from app.logger import get_logger
from app.repositories.firebase_chat_repo import firebase_chat_repo

logger = get_logger("worker.firebase_chat_listener")

ROOT = "crowd_funding_chat"


def start_listener():
    """Start Firebase RTDB listeners. Call once at worker startup."""
    logger.info("Starting Firebase chat listeners")

    # Listen for new messages
    messages_ref = get_rtdb_ref(f"{ROOT}/messages")
    messages_ref.listen(_on_message_event)

    # Listen for reaction shard changes
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

        # Update last message metadata
        firebase_chat_repo.update_last_message(conv_id, body, created_at)

        # Increment unread for the OTHER participant
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
```

- [ ] **Step 2: Commit**

```bash
git add Backend/app/worker/firebase_chat_listener.py
git commit -m "feat: add Firebase chat listener for messages and reactions"
```

---

## Task 18: Auto-Kick Integration Hooks

**Files:**
- Modify: ticket service (refund path)
- Modify: pledge service (refund path)
- Modify: sponsor service (bid rejection/cancellation path)

- [ ] **Step 1: Add hook to ticket refund**

In the ticket refund service function (wherever `refund_ticket` or similar exists), add after the refund is processed:

```python
# After successful refund
from app.services.chat import conversation_service
await conversation_service.revoke_access(db, user_id=user_id, event_id=event_id)
```

- [ ] **Step 2: Add hook to pledge refund**

In the pledge refund service function, add after refund:

```python
from app.services.chat import conversation_service
await conversation_service.revoke_access(db, user_id=user_id, event_id=event_id)
```

- [ ] **Step 3: Add hook to sponsor bid rejection/cancellation**

In the sponsor service where bid status is set to `rejected` or `cancelled`, add:

```python
from app.services.chat import conversation_service
await conversation_service.revoke_access(db, user_id=bid.sponsor_user_id, event_id=event_id)
```

- [ ] **Step 4: Add hook to ticket purchase — add to channel**

In the ticket purchase service, after successful purchase:

```python
from app.services.chat import channel_service
await channel_service.add_member(db, event_id=event_id, user_id=user_id, channel_type="customer")
```

- [ ] **Step 5: Add hook to pledge creation — add to channel**

In the pledge creation service, after successful pledge:

```python
from app.services.chat import channel_service
await channel_service.add_member(db, event_id=event_id, user_id=user_id, channel_type="customer")
```

- [ ] **Step 6: Add hook to sponsor bid acceptance — add to channel**

In the sponsor bid acceptance path (when status changes to `accepted` or `paid`):

```python
from app.services.chat import channel_service
await channel_service.add_member(db, event_id=event_id, user_id=bid.sponsor_user_id, channel_type="sponsor")
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add auto-kick and auto-add hooks for chat channel membership"
```

---

## Task 19: Event Transition Hook — Close Chats on Completion

**Files:**
- Modify: `Backend/app/worker/event_jobs.py` (or wherever event status transitions fire)

- [ ] **Step 1: Add chat close hook to event completion/cancellation**

In the event transition handler (where status changes to `completed` or `cancelled`), add:

```python
from app.services.chat import channel_service, conversation_service

await channel_service.close_event_channels(db, event_id=event.id)
await conversation_service.close_event_conversations(db, event_id=event.id)
```

This ensures all channels and conversations for the event become read-only when the event ends.

- [ ] **Step 2: Commit**

```bash
git add Backend/app/worker/event_jobs.py
git commit -m "feat: close chat channels/conversations on event completion"
```

---

## Task 20: Backend Tests (renumbered from 19)

**Files:**
- Create: `Backend/tests/test_chat_channel_service.py`
- Create: `Backend/tests/test_chat_conversation_service.py`
- Create: `Backend/tests/test_chat_routes.py`

- [ ] **Step 1: Write channel service tests**

Test cases:
- `test_create_channel_returns_existing` — idempotent creation
- `test_create_channel_non_organizer_rejected` — 403 for non-organizer
- `test_create_post_on_read_only_channel_rejected` — 409 for closed channel
- `test_create_post_success` — post created in Firebase
- `test_add_member_idempotent` — safe to call multiple times
- `test_remove_member` — removes from Firebase channel_members
- `test_close_event_channels` — sets all channels to read_only

Mock `firebase_chat_repo` methods and use the test database for PG operations.

- [ ] **Step 2: Write conversation service tests**

Test cases:
- `test_initiate_conversation_with_ticket` — customer DM created
- `test_initiate_conversation_without_access_rejected` — 403
- `test_initiate_conversation_idempotent` — returns existing
- `test_revoke_access_with_remaining_ties_keeps_access` — partial refund preserves access
- `test_revoke_access_no_ties_revokes` — sets DM read-only, removes from channel
- `test_close_event_conversations` — all convos set to read_only

- [ ] **Step 3: Write route integration tests**

Test cases:
- `test_create_channel_endpoint` — POST /chat/channels returns 201
- `test_create_post_endpoint` — POST /chat/channels/{id}/posts returns 201
- `test_list_posts_endpoint` — GET /chat/channels/{id}/posts returns list
- `test_initiate_conversation_endpoint` — POST /chat/conversations returns 201
- `test_list_conversations_endpoint` — GET /chat/conversations returns list

- [ ] **Step 4: Run tests**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_chat_channel_service.py tests/test_chat_conversation_service.py tests/test_chat_routes.py -v --tb=short`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Backend/tests/test_chat_channel_service.py Backend/tests/test_chat_conversation_service.py Backend/tests/test_chat_routes.py
git commit -m "test: add chat channel and conversation service tests"
```

---

## Task 21: Repository Helper Methods

Some service methods reference repo methods that may not exist yet. The engineer should verify these exist or add them:

**Files:**
- Possibly modify: `Backend/app/repositories/funding_repo.py`
- Possibly modify: `Backend/app/repositories/ticket_repo.py`
- Possibly modify: `Backend/app/repositories/sponsor_repo.py`
- Possibly modify: `Backend/app/repositories/event_repo.py`
- Possibly modify: `Backend/app/repositories/user_repo.py`

- [ ] **Step 1: Verify and add missing repo methods**

Methods needed by the chat services:

| Repository | Method | Returns |
|-----------|--------|---------|
| `funding_repo` | `has_active_pledge(db, event_id, user_id)` | `bool` |
| `funding_repo` | `get_pledger_user_ids(db, event_id)` | `list[int]` |
| `ticket_repo` | `has_active_ticket(db, event_id, user_id)` | `bool` |
| `ticket_repo` | `get_ticket_holder_user_ids(db, event_id)` | `list[int]` |
| `sponsor_repo` | `has_active_bid(db, event_id, user_id)` | `bool` |
| `sponsor_repo` | `get_accepted_sponsor_user_ids(db, event_id)` | `list[int]` |
| `event_repo` | `get_co_organizer_ids(db, event_id)` | `list[int]` |
| `user_repo` | `get_by_firebase_uid(db, firebase_uid)` | `User \| None` |

Check each — if it exists, skip. If not, add it following the existing repository patterns.

- [ ] **Step 2: Commit any additions**

```bash
git add Backend/app/repositories/
git commit -m "feat: add helper repo methods for chat service"
```

---

## Task Summary

| Task | Description | Dependencies |
|------|------------|-------------|
| 1 | Alembic migration | None |
| 2 | SQLAlchemy models + Pydantic schemas | Task 1 |
| 3 | Firebase RTDB helper + repository | None |
| 4 | PostgreSQL chat repository | Task 2 |
| 5 | Channel service | Tasks 3, 4, 21 |
| 6 | Conversation service | Tasks 3, 4, 21 |
| 7 | API routes | Tasks 5, 6 |
| 8 | Admin config setting | None |
| 9 | Firebase security rules | None |
| 10 | Frontend models | None |
| 11 | Frontend Firebase repository | Task 10 |
| 12 | Frontend provider | Task 11 |
| 13 | Frontend My Events tab | Task 12 |
| 14 | Frontend announcement channel screen | Task 12 |
| 15 | Frontend DM chat screen | Task 12 |
| 16 | Frontend organizer inbox | Task 12 |
| 17 | Firebase chat listener | Task 3 |
| 18 | Auto-kick integration hooks | Tasks 5, 6 |
| 19 | Event transition hook | Tasks 5, 6 |
| 20 | Backend tests | Tasks 5, 6, 7 |
| 21 | Repository helper methods | Before Tasks 5, 6 |

**Parallelization:** Tasks 1-4 + 8-10 + 21 can run in parallel. Tasks 5-7 depend on backend repos + helpers. Tasks 11-16 depend on frontend models. Tasks 17-20 can run after their deps.

**Note:** Archive/purge cron tasks (`archive_old_chat_data`, `purge_archived_chats`) are defined in the spec but deferred — they can be added after Phase 1 ships since chat data is small and retention is handled by the frontend hiding completed events.
