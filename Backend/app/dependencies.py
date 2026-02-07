"""
Global dependencies: DB session, current user, role checks.
"""
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base import get_db_session
from app.models.user import User
from app.core.security import get_current_user, get_current_user_optional as _get_current_user_optional
from app.models.user import UserRole


def require_role(*allowed_roles: UserRole):
    """Dependency factory: require current user to have one of the given roles."""
    async def _require_role(
        current_user: Annotated[User, Depends(get_current_user)]
    ) -> User:
        if current_user.role not in allowed_roles:
            from fastapi import HTTPException
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user
    return _require_role


# Type aliases for cleaner route signatures
DbSession = Annotated[AsyncSession, Depends(get_db_session)]
CurrentUser = Annotated[User, Depends(get_current_user)]
CurrentUserOptional = Annotated[User | None, Depends(_get_current_user_optional)]
