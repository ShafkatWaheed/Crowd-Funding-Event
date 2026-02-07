"""
Users: profile (GET/PATCH /me). Admin: list users.
"""
from fastapi import APIRouter

from app.dependencies import CurrentUser, DbSession, require_role
from app.models.user import UserRole
from app.schemas import MeResponse, MeUpdate

router = APIRouter()


@router.get("", response_model=MeResponse)
async def get_me(current_user: CurrentUser):
    """Current user profile."""
    return MeResponse(
        id=current_user.id,
        email=current_user.email,
        display_name=current_user.display_name,
        role=current_user.role.value,
    )


@router.patch("", response_model=MeResponse)
async def update_me(
    body: MeUpdate,
    current_user: CurrentUser,
    db: DbSession,
):
    """Update current user profile."""
    if body.display_name is not None:
        current_user.display_name = body.display_name
    await db.flush()
    await db.refresh(current_user)
    return MeResponse(
        id=current_user.id,
        email=current_user.email,
        display_name=current_user.display_name,
        role=current_user.role.value,
    )
