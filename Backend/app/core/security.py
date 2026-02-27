"""
Firebase ID token verification and current user resolution.
"""
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.firebase import verify_id_token
from app.db.base import get_read_db_session
from app.logger import get_logger
from app.models.user import User

logger = get_logger("core.security")

security = HTTPBearer(auto_error=False)


async def verify_firebase_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> Optional[str]:
    """
    Verify Firebase ID token from Authorization header and return firebase_uid.
    Returns None if no credentials; raises 401 if token invalid.
    """
    if not credentials:
        return None
    try:
        decoded = verify_id_token(credentials.credentials)
        uid = decoded.get("uid")
        logger.debug("Firebase token verified, uid=%s", uid)
        return uid
    except ValueError:
        logger.warning("Token verification rejected")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    db: AsyncSession = Depends(get_read_db_session),
    firebase_uid: Optional[str] = Depends(verify_firebase_token),
) -> User:
    """Load current user from DB by firebase_uid. Requires valid Firebase token."""
    if not firebase_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
    user = result.scalar_one_or_none()
    if not user:
        logger.warning("No DB user for firebase_uid=%s", firebase_uid)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    logger.debug("Resolved user id=%d role=%s", user.id, user.role.value)
    return user


async def get_current_user_optional(
    db: AsyncSession = Depends(get_read_db_session),
    firebase_uid: Optional[str] = Depends(verify_firebase_token),
) -> Optional[User]:
    """
    Load current user from DB when Bearer token is present and valid.
    Returns None if no credentials or user not in DB (e.g. before /auth/verify).
    Raises 401 only if token is present but invalid/expired.
    """
    if not firebase_uid:
        return None
    result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
    return result.scalar_one_or_none()
