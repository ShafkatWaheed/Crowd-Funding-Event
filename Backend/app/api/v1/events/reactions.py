"""
Event reactions: like/dislike, my-reaction.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.dependencies import DbSession, ReadDbSession, require_role
from app.rate_limit import limiter, dynamic_limit
from app.models.event import EventReaction
from app.models.user import User, UserRole
from app.services import event as event_service
from app.repositories.event_repo import event_repo

router = APIRouter()


@router.post("/{event_id}/react")
@limiter.limit(dynamic_limit("social_action", "30/minute"))
async def react_to_event(
    request: Request,
    event_id: int,
    db: DbSession,
    reaction: str = Query(..., description="'like' or 'dislike'"),
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin, UserRole.sponsor)),
):
    """Like or dislike an event. Toggles: same reaction again removes it; different reaction switches it."""
    if reaction not in ("like", "dislike"):
        raise HTTPException(status_code=400, detail="reaction must be 'like' or 'dislike'")

    event = await event_service.get_or_404(db, event_id)

    existing = await event_repo.get_user_reaction(db, event_id, current_user.id)

    if existing:
        if existing.reaction == reaction:
            if reaction == "like":
                event.like_count = max(0, event.like_count - 1)
            else:
                event.dislike_count = max(0, event.dislike_count - 1)
            await event_repo.delete_reaction(db, existing)
            return {"action": "removed", "reaction": reaction, "like_count": event.like_count, "dislike_count": event.dislike_count}
        else:
            if existing.reaction == "like":
                event.like_count = max(0, event.like_count - 1)
            else:
                event.dislike_count = max(0, event.dislike_count - 1)
            existing.reaction = reaction
            if reaction == "like":
                event.like_count += 1
            else:
                event.dislike_count += 1
            await event_repo.flush(db)
            return {"action": "switched", "reaction": reaction, "like_count": event.like_count, "dislike_count": event.dislike_count}
    else:
        new_reaction = EventReaction(
            event_id=event_id,
            user_id=current_user.id,
            reaction=reaction,
        )
        await event_repo.create_reaction(db, new_reaction)
        if reaction == "like":
            event.like_count += 1
        else:
            event.dislike_count += 1
        await event_repo.flush(db)
        return {"action": "added", "reaction": reaction, "like_count": event.like_count, "dislike_count": event.dislike_count}


@router.get("/{event_id}/my-reaction")
async def get_my_reaction(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin, UserRole.sponsor)),
):
    """Check the current user's reaction on an event."""
    existing = await event_repo.get_user_reaction(db, event_id, current_user.id)
    return {"reaction": existing.reaction if existing else None}
