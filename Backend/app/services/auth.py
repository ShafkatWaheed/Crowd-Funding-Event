"""
Firebase verify + user upsert: verify ID token, create or update user in DB.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.firebase import verify_id_token
from app.models.user import User, UserRole


async def verify_and_upsert_user(
    db: AsyncSession,
    id_token: str,
    *,
    sign_up_role: str | None = None,
    terms_accepted_at=None,
) -> User:
    """
    Verify Firebase ID token and create or update user in DB.
    - Existing user: update email/display_name only (role unchanged).
    - New user: create with role from sign_up_role if "customer" or "organizer", else customer.
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

    # New user: use requested role only if allowed (never admin)
    role = UserRole.customer
    if sign_up_role in ("customer", "organizer"):
        role = UserRole(sign_up_role)

    user = User(
        firebase_uid=uid,
        email=email,
        display_name=display_name,
        role=role,
        terms_accepted_at=terms_accepted_at,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user
