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
