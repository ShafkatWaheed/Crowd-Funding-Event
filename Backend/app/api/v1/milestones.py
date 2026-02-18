"""
Funding Milestones API — CRUD + per-milestone reactions.
All endpoints gated by the feature_milestones_enabled flag.
"""
from fastapi import APIRouter, Depends, Query

from app.dependencies import DbSession, CurrentUserOptional, require_role, require_feature
from app.models.user import User, UserRole
from app.schemas.milestone import (
    MilestoneCreate,
    MilestoneUpdate,
    MilestoneResponse,
    MilestoneReactionResponse,
)
from app.services import milestone as milestone_service

router = APIRouter()

_feature_guard = Depends(require_feature("feature_milestones_enabled"))


# ── List milestones (public) ──────────────────────────────

@router.get(
    "/{event_id}/milestones",
    response_model=list[MilestoneResponse],
    dependencies=[_feature_guard],
)
async def list_milestones(event_id: int, db: DbSession):
    return await milestone_service.list_milestones(db, event_id)


# ── Create milestone (organizer) ─────────────────────────

@router.post(
    "/{event_id}/milestones",
    response_model=MilestoneResponse,
    status_code=201,
    dependencies=[_feature_guard],
)
async def create_milestone(
    event_id: int,
    body: MilestoneCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await milestone_service.create_milestone(db, event_id, body, current_user)


# ── Update milestone (organizer) ─────────────────────────

@router.patch(
    "/{event_id}/milestones/{milestone_id}",
    response_model=MilestoneResponse,
    dependencies=[_feature_guard],
)
async def update_milestone(
    event_id: int,
    milestone_id: int,
    body: MilestoneUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await milestone_service.update_milestone(db, milestone_id, body, current_user)


# ── Delete milestone (organizer) ─────────────────────────

@router.delete(
    "/{event_id}/milestones/{milestone_id}",
    status_code=204,
    dependencies=[_feature_guard],
)
async def delete_milestone(
    event_id: int,
    milestone_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    await milestone_service.delete_milestone(db, milestone_id, current_user)


# ── React (like/dislike) to a milestone ──────────────────

@router.post(
    "/{event_id}/milestones/{milestone_id}/react",
    response_model=MilestoneReactionResponse,
    dependencies=[_feature_guard],
)
async def react_to_milestone(
    event_id: int,
    milestone_id: int,
    db: DbSession,
    reaction: str = Query(..., description="'like' or 'dislike'"),
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    return await milestone_service.react_to_milestone(
        db, milestone_id, current_user.id, reaction
    )


# ── Get current user's reaction on a milestone ──────────

@router.get(
    "/{event_id}/milestones/{milestone_id}/my-reaction",
    dependencies=[_feature_guard],
)
async def get_my_milestone_reaction(
    event_id: int,
    milestone_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    return await milestone_service.get_my_reaction(db, milestone_id, current_user.id)
