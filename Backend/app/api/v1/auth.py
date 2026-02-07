"""
Auth: verify Firebase token, create/update user in DB.
Current user profile: see users router (GET /me).
"""
from fastapi import APIRouter, HTTPException

from app.dependencies import DbSession
from app.schemas import VerifyBody, VerifyResponse
from app.services import auth as auth_service

router = APIRouter()


@router.post("/verify", response_model=VerifyResponse)
async def verify(body: VerifyBody, db: DbSession):
    """Verify Firebase ID token and create/update user. Returns user profile."""
    try:
        user = await auth_service.verify_and_upsert_user(db, body.id_token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    return VerifyResponse(
        user_id=user.id,
        email=user.email,
        display_name=user.display_name,
        role=user.role.value,
    )
