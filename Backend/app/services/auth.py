"""
Firebase verify + user upsert: verify ID token, create or update user in DB.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.firebase import verify_id_token
from app.models.user import User, UserRole


async def verify_and_upsert_user(db: AsyncSession, id_token: str) -> User:
    """
    Verify Firebase ID token and create or update user in DB.
    New users get role customer. Existing users get email/display_name updated.
    Raises ValueError if token is invalid (caller should map to 401).
    """
    decoded = verify_id_token(id_token)
    uid = decoded.get("uid")
    if not uid:
        raise ValueError("Token missing uid")
    email = (decoded.get("email") or "").strip() or f"{uid}@firebase.local"
    display_name = (decoded.get("name") or "").strip() or None

    result = await db.execute(select(User).where(User.firebase_uid == uid))
    user = result.scalar_one_or_none()
    if user:
        user.email = email
        if display_name is not None:
            user.display_name = display_name
        await db.flush()
        await db.refresh(user)
        return user

    user = User(
        firebase_uid=uid,
        email=email,
        display_name=display_name,
        role=UserRole.customer,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user
