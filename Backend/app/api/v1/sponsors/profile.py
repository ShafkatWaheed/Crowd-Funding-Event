"""Sponsor profile endpoints."""
from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature
from app.logger import get_logger, log_step
from app.schemas.sponsor import SponsorProfileCreate, SponsorProfileUpdate, SponsorProfileResponse
from app.services import sponsor as sponsor_svc

logger = get_logger("api.sponsors.profile")
router = APIRouter(dependencies=[Depends(require_feature("feature_sponsors_enabled"))])


@router.post(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
    status_code=201,
)
async def create_sponsor_profile(
    data: SponsorProfileCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Creating sponsor profile", user_id=current_user.id, company_name=data.company_name)
    profile = await sponsor_svc.create_profile(db, current_user, data)
    await db.commit()
    await db.refresh(profile)
    return profile


@router.get(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
)
async def get_sponsor_profile(db: ReadDbSession, current_user: CurrentUser):
    profile = await sponsor_svc.get_profile(db, current_user.id)
    if not profile:
        logger.warning("Sponsor profile not found", extra={"user_id": current_user.id})
        raise HTTPException(status_code=404, detail="Sponsor profile not found")
    return profile


@router.patch(
    "/me/sponsor-profile",
    response_model=SponsorProfileResponse,
)
async def update_sponsor_profile(
    data: SponsorProfileUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Updating sponsor profile", user_id=current_user.id)
    profile = await sponsor_svc.update_profile(db, current_user.id, data)
    await db.commit()
    await db.refresh(profile)
    return profile
