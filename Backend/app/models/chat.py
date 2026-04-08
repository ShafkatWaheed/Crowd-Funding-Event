"""SQLAlchemy models for chat channels and conversations."""
from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
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
