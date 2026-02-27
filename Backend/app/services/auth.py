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
    display_name_override: str | None = None,
    terms_accepted_at=None,
    birthday=None,
) -> User:
    """
    Verify Firebase ID token and create or update user in DB.
    - Existing user: update email/display_name only (role unchanged).
    - New user: create with role from sign_up_role if "customer", "organizer", or "sponsor", else customer.
    display_name_override takes precedence over the token's name claim
    (Firebase doesn't embed it into the token immediately after updateDisplayName).
    Raises ValueError if token is invalid (caller should map to 401).
    """
    decoded = verify_id_token(id_token)
    uid = decoded.get("uid")
    if not uid:
        raise ValueError("Token missing uid")
    email = (decoded.get("email") or "").strip() or f"{uid}@firebase.local"
    display_name = (
        (display_name_override or "").strip()
        or (decoded.get("name") or "").strip()
        or None
    )

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
    if sign_up_role in ("customer", "organizer", "sponsor"):
        role = UserRole(sign_up_role)

    # Birthday is mandatory for all signups (customer, organizer, sponsor) for age verification
    if birthday is None:
        raise ValueError("Birthday is required for registration (age verification)")
    from datetime import date as date_type
    from app.services.age_verification import calculate_age
    if isinstance(birthday, str):
        birthday = date_type.fromisoformat(birthday)
    age = calculate_age(birthday)
    if age < 13:
        raise ValueError("You must be at least 13 years old to register")

    user = User(
        firebase_uid=uid,
        email=email,
        display_name=display_name,
        role=role,
        terms_accepted_at=terms_accepted_at,
        birthday=birthday,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user
