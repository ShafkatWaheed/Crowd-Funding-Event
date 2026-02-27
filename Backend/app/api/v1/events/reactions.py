"""
Event reactions: like/dislike, my-reaction.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import select

from app.dependencies import DbSession, ReadDbSession, require_role
from app.rate_limit import limiter, dynamic_limit
from app.models.event import EventReaction
from app.models.user import User, UserRole
from app.services import event as event_service

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

    q = select(EventReaction).where(
        EventReaction.event_id == event_id,
        EventReaction.user_id == current_user.id,
    )
    existing = (await db.execute(q)).scalar_one_or_none()

    if existing:
        if existing.reaction == reaction:
            if reaction == "like":
                event.like_count = max(0, event.like_count - 1)
            else:
                event.dislike_count = max(0, event.dislike_count - 1)
            await db.delete(existing)
            await db.flush()
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
            await db.flush()
            return {"action": "switched", "reaction": reaction, "like_count": event.like_count, "dislike_count": event.dislike_count}
    else:
        new_reaction = EventReaction(
            event_id=event_id,
            user_id=current_user.id,
            reaction=reaction,
        )
        db.add(new_reaction)
        if reaction == "like":
            event.like_count += 1
        else:
            event.dislike_count += 1
        await db.flush()
        return {"action": "added", "reaction": reaction, "like_count": event.like_count, "dislike_count": event.dislike_count}


@router.get("/{event_id}/my-reaction")
async def get_my_reaction(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin, UserRole.sponsor)),
):
    """Check the current user's reaction on an event."""
    q = select(EventReaction).where(
        EventReaction.event_id == event_id,
        EventReaction.user_id == current_user.id,
    )
    existing = (await db.execute(q)).scalar_one_or_none()
    return {"reaction": existing.reaction if existing else None}
