"""
EventPoll data-access layer.

All SQLAlchemy queries for event polls and votes live here.
"""
from datetime import datetime, timezone

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event_poll import EventPoll, EventPollVote
from app.repositories.base import BaseRepository


class EventPollRepository(BaseRepository[EventPoll]):
    model_class = EventPoll

    async def get_active_for_event(
        self, db: AsyncSession, event_id: int
    ) -> EventPoll | None:
        """Return the currently active (open) poll for an event, or None."""
        result = await db.execute(
            select(EventPoll)
            .options(selectinload(EventPoll.votes))
            .where(
                EventPoll.event_id == event_id,
                EventPoll.is_active.is_(True),
                EventPoll.is_closed.is_(False),
            )
        )
        return result.scalar_one_or_none()

    async def get_by_id_with_votes(
        self, db: AsyncSession, poll_id: int
    ) -> EventPoll | None:
        """Get a poll by primary key with votes eager-loaded."""
        result = await db.execute(
            select(EventPoll)
            .options(selectinload(EventPoll.votes))
            .where(EventPoll.id == poll_id)
        )
        return result.scalar_one_or_none()

    async def list_for_event(
        self, db: AsyncSession, event_id: int
    ) -> list[EventPoll]:
        """Return all polls for an event ordered newest-first (organizer view)."""
        result = await db.execute(
            select(EventPoll)
            .options(selectinload(EventPoll.votes))
            .where(EventPoll.event_id == event_id)
            .order_by(EventPoll.created_at.desc())
        )
        return list(result.scalars().all())

    async def create(self, db: AsyncSession, poll: EventPoll) -> EventPoll:
        """Persist a new poll."""
        db.add(poll)
        await db.flush()
        await db.refresh(poll)
        return poll

    async def close(self, db: AsyncSession, poll: EventPoll) -> EventPoll:
        """Close a poll (end voting, reveal results)."""
        poll.is_closed = True
        poll.is_active = False
        poll.closed_at = datetime.now(timezone.utc)
        await db.flush()
        await db.refresh(poll)
        return poll

    async def deactivate_all_for_event(
        self, db: AsyncSession, event_id: int
    ) -> None:
        """Set is_active=False for all open polls on an event (before creating a new one)."""
        await db.execute(
            update(EventPoll)
            .where(EventPoll.event_id == event_id, EventPoll.is_active.is_(True))
            .values(is_active=False)
        )

    async def get_vote(
        self, db: AsyncSession, poll_id: int, user_id: int
    ) -> EventPollVote | None:
        """Return the vote cast by user_id on poll_id, or None."""
        result = await db.execute(
            select(EventPollVote).where(
                EventPollVote.poll_id == poll_id,
                EventPollVote.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def cast_vote(
        self,
        db: AsyncSession,
        *,
        poll_id: int,
        user_id: int,
        option_index: int,
    ) -> EventPollVote:
        """Record a vote. Assumes no duplicate (caller must check first)."""
        vote = EventPollVote(
            poll_id=poll_id,
            user_id=user_id,
            option_index=option_index,
        )
        db.add(vote)
        await db.flush()
        await db.refresh(vote)
        return vote

    async def get_tally(
        self, db: AsyncSession, poll_id: int
    ) -> dict[int, int]:
        """Return {option_index: vote_count} for a poll."""
        rows = await db.execute(
            select(EventPollVote.option_index, func.count().label("cnt"))
            .where(EventPollVote.poll_id == poll_id)
            .group_by(EventPollVote.option_index)
        )
        return {row.option_index: row.cnt for row in rows}


event_poll_repo = EventPollRepository()
