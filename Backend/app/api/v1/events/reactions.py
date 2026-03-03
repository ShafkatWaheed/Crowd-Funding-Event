"""
Event reactions: like/dislike, my-reaction.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.dependencies import DbSession, ReadDbSession, require_role
from app.rate_limit import limiter, dynamic_limit
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
    return await event_service.react_to_event(db, event_id, current_user.id, reaction)


@router.get("/{event_id}/my-reaction")
async def get_my_reaction(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin, UserRole.sponsor)),
):
    """Check the current user's reaction on an event."""
    existing = await event_repo.get_user_reaction(db, event_id, current_user.id)
    return {"reaction": existing.reaction if existing else None}
