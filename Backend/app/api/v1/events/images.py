"""
Event images: list, add by URL, upload, delete.
"""
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile
from sqlalchemy import select

from app.dependencies import DbSession, ReadDbSession, require_role
from app.logger import get_logger, log_step
from app.rate_limit import limiter, dynamic_limit
from app.services.upload_validation import validate_upload
from app.models.image import EventImage
from app.models.user import User, UserRole
from app.schemas import EventImageResponse
from app.core.exceptions import ForbiddenError, NotFoundError
from app.services import event as event_service

router = APIRouter()
logger = get_logger("api.events.images")


@router.get("/{event_id}/images", response_model=list[EventImageResponse])
async def list_event_images(event_id: int, db: ReadDbSession):
    """List images for an event (public)."""
    q = (
        select(EventImage)
        .where(EventImage.event_id == event_id)
        .order_by(EventImage.display_order.asc(), EventImage.created_at.asc())
    )
    result = await db.execute(q)
    return [EventImageResponse.model_validate(img) for img in result.scalars().all()]


@router.post("/{event_id}/images", response_model=EventImageResponse)
async def add_event_image(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    image_url: str = Query(..., description="URL of the image"),
    caption: str | None = Query(None),
    display_order: int = Query(0),
):
    """Add an image to event by URL (organizer/admin)."""
    log_step(logger, "Adding event image by URL", user_id=current_user.id, event_id=event_id)
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        logger.warning("Image operation rejected: user cannot edit event", extra={"user_id": current_user.id, "event_id": event_id})
        raise ForbiddenError("You cannot manage this event")
    policy = await event_service.get_effective_policy(db, event)
    max_imgs = policy.get("event_max_images")
    if max_imgs and max_imgs > 0:
        from sqlalchemy import func as _fn
        current = (await db.execute(
            select(_fn.count()).where(EventImage.event_id == event_id)
        )).scalar_one()
        if int(current) >= max_imgs:
            logger.warning("Add image rejected: max images reached", extra={"event_id": event_id, "max_imgs": max_imgs})
            raise HTTPException(status_code=409, detail=f"Max {max_imgs} images per event")
    img = EventImage(
        event_id=event_id,
        image_url=image_url,
        caption=caption,
        display_order=display_order,
    )
    db.add(img)
    await db.flush()
    await db.refresh(img)
    return EventImageResponse.model_validate(img)


@router.post("/{event_id}/images/upload", response_model=EventImageResponse)
@limiter.limit(dynamic_limit("file_upload", "10/minute"))
async def upload_event_image(
    request: Request,
    event_id: int,
    db: DbSession,
    file: UploadFile = File(...),
    caption: str | None = Form(None),
    display_order: int = Form(0),
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Upload an image file for an event (organizer/admin)."""
    log_step(logger, "Uploading event image", user_id=current_user.id, event_id=event_id)
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        logger.warning("Image operation rejected: user cannot edit event", extra={"user_id": current_user.id, "event_id": event_id})
        raise ForbiddenError("You cannot manage this event")
    policy = await event_service.get_effective_policy(db, event)
    max_imgs = policy.get("event_max_images")
    if max_imgs and max_imgs > 0:
        from sqlalchemy import func as _fn
        current = (await db.execute(
            select(_fn.count()).where(EventImage.event_id == event_id)
        )).scalar_one()
        if int(current) >= max_imgs:
            logger.warning("Upload image rejected: max images reached", extra={"event_id": event_id, "max_imgs": max_imgs})
            raise HTTPException(status_code=409, detail=f"Max {max_imgs} images per event")

    contents = await validate_upload(db, file, "image")

    ext = Path(file.filename or "img.jpg").suffix.lower() or ".jpg"
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        ext = ".jpg"
    filename = f"{event_id}_{uuid.uuid4().hex[:12]}{ext}"

    upload_dir = Path(__file__).resolve().parent.parent.parent.parent.parent / "static" / "uploads"
    upload_dir.mkdir(parents=True, exist_ok=True)
    dest = upload_dir / filename
    dest.write_bytes(contents)

    image_url = f"/static/uploads/{filename}"
    img = EventImage(
        event_id=event_id,
        image_url=image_url,
        caption=caption,
        display_order=display_order,
    )
    db.add(img)
    await db.flush()
    await db.refresh(img)
    return EventImageResponse.model_validate(img)


@router.delete("/{event_id}/images/{image_id}")
async def delete_event_image(
    event_id: int,
    image_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete an image from event (organizer/admin)."""
    log_step(logger, "Deleting event image", user_id=current_user.id, event_id=event_id, image_id=image_id)
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        logger.warning("Image operation rejected: user cannot edit event", extra={"user_id": current_user.id, "event_id": event_id})
        raise ForbiddenError("You cannot manage this event")
    q = select(EventImage).where(EventImage.id == image_id, EventImage.event_id == event_id)
    result = await db.execute(q)
    img = result.scalar_one_or_none()
    if not img:
        raise NotFoundError("Image", image_id)
    await db.delete(img)
    await db.flush()
    return {"ok": True}
