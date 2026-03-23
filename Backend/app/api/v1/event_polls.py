"""
Live event polls: GET/POST /events/{id}/polls, POST /events/{id}/polls/{pid}/vote|close
"""
from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import CurrentUser, CurrentUserOptional, DbSession, ReadDbSession, require_role
from app.models.user import User, UserRole
from app.repositories.event_poll_repo import event_poll_repo
from app.schemas.event_poll import PollCreate, PollResponse, PollVoteRequest
from app.services import event as event_service
from app.services import event_poll as poll_service

router = APIRouter()


@router.get("/{event_id}/polls/active", response_model=PollResponse | None)
async def get_active_poll(
    event_id: int,
    db: ReadDbSession,
    current_user: CurrentUserOptional = None,
):
    """Return the currently active poll for an event, or null if none.

    Frontend polls this endpoint every 5 seconds while the event is live.
    """
    poll = await poll_service.get_active_poll(db, event_id)
    if poll is None:
        return None
    tally = await event_poll_repo.get_tally(db, poll.id)
    viewer_vote = None
    if current_user is not None:
        vote = await event_poll_repo.get_vote(db, poll.id, current_user.id)
        viewer_vote = vote.option_index if vote else None
    return poll_service.build_poll_response(poll, tally, viewer_vote)


@router.get("/{event_id}/polls", response_model=list[PollResponse])
async def list_polls(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List all polls for an event (organizer/admin only)."""
    polls = await poll_service.list_polls(db, event_id)
    results = []
    for poll in polls:
        tally = await event_poll_repo.get_tally(db, poll.id)
        vote = await event_poll_repo.get_vote(db, poll.id, current_user.id)
        results.append(
            poll_service.build_poll_response(poll, tally, vote.option_index if vote else None)
        )
    return results


@router.post("/{event_id}/polls", response_model=PollResponse, status_code=201)
async def create_poll(
    event_id: int,
    body: PollCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create a new poll for a live event. Requires organizer ownership or admin."""
    event = await event_service.get_or_404(db, event_id)
    # Ownership check: organizer must own the event (admin may bypass)
    if current_user.role != UserRole.admin and event.organizer_id != current_user.id:
        raise HTTPException(status_code=403, detail="You do not own this event")

    poll = await poll_service.create_poll(db, event, current_user.id, body)
    await db.commit()
    await db.refresh(poll)

    # Notify all registrants asynchronously
    try:
        from app.worker.redis_pool import enqueue as arq_enqueue
        await arq_enqueue("notify_poll_created", event_id=event_id, poll_id=poll.id)
    except Exception:
        pass

    return poll_service.build_poll_response(poll, {}, None)


@router.post("/{event_id}/polls/{poll_id}/vote", response_model=PollResponse)
async def cast_vote(
    event_id: int,
    poll_id: int,
    body: PollVoteRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    """Cast a vote on the active poll. One vote per user per poll."""
    poll = await poll_service.get_poll_or_404(db, poll_id)
    if poll.event_id != event_id:
        raise HTTPException(status_code=404, detail="Poll not found for this event")
    await poll_service.vote(db, poll, current_user.id, body)
    await db.commit()
    await db.refresh(poll)
    tally = await event_poll_repo.get_tally(db, poll.id)
    vote = await event_poll_repo.get_vote(db, poll.id, current_user.id)
    return poll_service.build_poll_response(poll, tally, vote.option_index if vote else None)


@router.post("/{event_id}/polls/{poll_id}/close", response_model=PollResponse)
async def close_poll(
    event_id: int,
    poll_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Close a poll (stop accepting votes, reveal results)."""
    poll = await poll_service.get_poll_or_404(db, poll_id)
    if poll.event_id != event_id:
        raise HTTPException(status_code=404, detail="Poll not found for this event")
    poll_service.check_ownership(poll, current_user.id, current_user.role == UserRole.admin)
    poll = await poll_service.close_poll(db, poll)
    await db.commit()
    await db.refresh(poll)
    tally = await event_poll_repo.get_tally(db, poll.id)
    return poll_service.build_poll_response(poll, tally, None)
