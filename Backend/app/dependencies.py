"""
Global dependencies: DB session, current user, role checks, feature flags.
"""
from typing import Annotated

from fastapi import Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base import get_db_session, get_read_db_session
from app.models.user import User
from app.core.security import get_current_user, get_current_user_optional as _get_current_user_optional
from app.models.user import UserRole


def require_role(*allowed_roles: UserRole):
    """Dependency factory: require current user to have one of the given roles."""
    async def _require_role(
        current_user: Annotated[User, Depends(get_current_user)]
    ) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user
    return _require_role


def require_feature(key: str):
    """Dependency factory: returns 403 if the given feature flag is disabled."""
    async def _guard(db: Annotated[AsyncSession, Depends(get_db_session)]):
        from app.services import platform_settings as settings_svc
        if not await settings_svc.get_bool(db, key):
            raise HTTPException(status_code=403, detail=f"Feature disabled: {key}")
    return _guard


def require_kyc():
    """Dependency factory: blocks if KYC is required for the user's role and they are not verified."""
    async def _guard(
        db: Annotated[AsyncSession, Depends(get_db_session)],
        current_user: Annotated[User, Depends(get_current_user)],
    ):
        if current_user.role == UserRole.admin:
            return
        from app.services import platform_settings as settings_svc
        key = f"kyc_required_{current_user.role.value}"
        if await settings_svc.get_bool(db, key) and not current_user.kyc_verified:
            raise HTTPException(
                status_code=403,
                detail="KYC verification required. Complete identity verification in your profile.",
            )
    return _guard


# Type aliases for cleaner route signatures
DbSession = Annotated[AsyncSession, Depends(get_db_session)]
ReadDbSession = Annotated[AsyncSession, Depends(get_read_db_session)]
CurrentUser = Annotated[User, Depends(get_current_user)]
CurrentUserOptional = Annotated[User | None, Depends(_get_current_user_optional)]
