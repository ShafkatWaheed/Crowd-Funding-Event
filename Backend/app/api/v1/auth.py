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
    """Verify Firebase ID token and create/update user. New users can sign up as customer or organizer via body.role."""
    try:
        user = await auth_service.verify_and_upsert_user(
            db,
            body.id_token,
            sign_up_role=body.role,
            display_name_override=body.display_name,
            terms_accepted_at=body.terms_accepted_at,
        )
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    return VerifyResponse(
        user_id=user.id,
        email=user.email,
        display_name=user.display_name,
        role=user.role.value,
        terms_accepted_at=user.terms_accepted_at,
    )
