"""Sponsor profile CRUD."""
from fastapi import HTTPException
from sqlalchemy import select

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.sponsor import SponsorProfile
from app.schemas.sponsor import SponsorProfileCreate, SponsorProfileUpdate

logger = get_logger("svc.sponsor.profile")


async def get_profile(db: AsyncSession, user_id: int) -> SponsorProfile | None:
    q = select(SponsorProfile).where(SponsorProfile.user_id == user_id)
    return (await db.execute(q)).scalar_one_or_none()


async def create_profile(
    db: AsyncSession, user: User, data: SponsorProfileCreate
) -> SponsorProfile:
    log_step(logger, "Create sponsor profile", user_id=user.id)
    existing = await get_profile(db, user.id)
    if existing:
        logger.warning("Create profile rejected: already exists", extra={"user_id": user.id})
        raise HTTPException(status_code=409, detail="Sponsor profile already exists")

    profile = SponsorProfile(
        user_id=user.id,
        company_name=data.company_name,
        contact_name=data.contact_name,
        profession=data.profession,
        logo_url=data.logo_url,
        description=data.description,
        website_url=data.website_url,
    )
    db.add(profile)

    if user.role == UserRole.customer:
        user.role = UserRole.sponsor
        db.add(user)

    await db.flush()
    await db.refresh(profile)
    logger.info("Sponsor profile created", extra={"profile_id": profile.id, "user_id": user.id})
    return profile


async def update_profile(
    db: AsyncSession, user_id: int, data: SponsorProfileUpdate
) -> SponsorProfile:
    log_step(logger, "Update sponsor profile", user_id=user_id)
    profile = await get_profile(db, user_id)
    if not profile:
        logger.warning("Update profile: not found", extra={"user_id": user_id})
        raise HTTPException(status_code=404, detail="Sponsor profile not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(profile, field, value)

    await db.flush()
    await db.refresh(profile)
    logger.info("Sponsor profile updated", extra={"profile_id": profile.id, "user_id": user_id})
    return profile
