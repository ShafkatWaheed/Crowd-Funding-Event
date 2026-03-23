"""
Event poll service: business logic for live event polling.

Zero db.* calls — all data access goes through event_poll_repo.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from fastapi import HTTPException
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.event import Event, EventStatus
from app.models.event_poll import EventPoll, EventPollVote
from app.repositories.event_poll_repo import event_poll_repo
from app.schemas.event_poll import PollCreate, PollOptionResult, PollResponse, PollVoteRequest


async def get_poll_or_404(db: AsyncSession, poll_id: int) -> EventPoll:
    """Fetch a poll (with votes) or raise NotFoundError."""
    poll = await event_poll_repo.get_by_id_with_votes(db, poll_id)
    if poll is None:
        raise NotFoundError("Poll", poll_id)
    return poll


def check_ownership(poll: EventPoll, user_id: int, is_admin: bool) -> None:
    """Raise ForbiddenError if the caller does not own this poll."""
    if not is_admin and poll.organizer_id != user_id:
        raise ForbiddenError("You do not have permission to modify this poll")


async def list_polls(db: AsyncSession, event_id: int) -> list[EventPoll]:
    """Return all polls for an event (organizer view)."""
    return await event_poll_repo.list_for_event(db, event_id)


async def get_active_poll(db: AsyncSession, event_id: int) -> EventPoll | None:
    """Return the active poll for an event, or None."""
    return await event_poll_repo.get_active_for_event(db, event_id)


async def create_poll(
    db: AsyncSession,
    event: Event,
    organizer_id: int,
    body: PollCreate,
) -> EventPoll:
    """Create a new poll for a live event. Deactivates any currently active poll first."""
    if event.status != EventStatus.live:
        raise HTTPException(status_code=400, detail="Polls can only be created during a live event")

    # Deactivate any currently active poll before creating a new one
    await event_poll_repo.deactivate_all_for_event(db, event.id)

    poll = EventPoll(
        event_id=event.id,
        organizer_id=organizer_id,
        question=body.question,
        options=body.options,
        show_results_while_open=body.show_results_while_open,
    )
    return await event_poll_repo.create(db, poll)


async def vote(
    db: AsyncSession,
    poll: EventPoll,
    user_id: int,
    body: PollVoteRequest,
) -> EventPollVote:
    """Cast a vote on a poll."""
    if poll.is_closed or not poll.is_active:
        raise HTTPException(status_code=400, detail="This poll is no longer accepting votes")
    if body.option_index < 0 or body.option_index >= len(poll.options):
        raise HTTPException(status_code=400, detail="Invalid option index")

    existing = await event_poll_repo.get_vote(db, poll.id, user_id)
    if existing is not None:
        raise ConflictError("You have already voted on this poll")

    return await event_poll_repo.cast_vote(
        db, poll_id=poll.id, user_id=user_id, option_index=body.option_index
    )


async def close_poll(db: AsyncSession, poll: EventPoll) -> EventPoll:
    """Close a poll (stop accepting votes)."""
    if poll.is_closed:
        raise HTTPException(status_code=400, detail="This poll is already closed")
    return await event_poll_repo.close(db, poll)


def build_poll_response(
    poll: EventPoll,
    tally: dict[int, int],
    viewer_vote_index: int | None,
) -> PollResponse:
    """Construct a PollResponse DTO, applying show_results_while_open logic."""
    total = sum(tally.values())
    show_results = poll.is_closed or poll.show_results_while_open

    results: list[PollOptionResult] | None = None
    if show_results:
        results = [
            PollOptionResult(
                index=i,
                text=opt,
                vote_count=tally.get(i, 0),
                percentage=round(tally.get(i, 0) / total * 100, 1) if total > 0 else 0.0,
            )
            for i, opt in enumerate(poll.options)
        ]

    return PollResponse(
        id=poll.id,
        event_id=poll.event_id,
        organizer_id=poll.organizer_id,
        question=poll.question,
        options=poll.options,
        is_active=poll.is_active,
        is_closed=poll.is_closed,
        show_results_while_open=poll.show_results_while_open,
        created_at=poll.created_at,
        closed_at=poll.closed_at,
        viewer_vote_index=viewer_vote_index,
        results=results,
        total_votes=total,
    )
