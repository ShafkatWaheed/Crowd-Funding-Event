"""
Event Schedule API — CRUD + bulk create + image upload + Excel export.
All endpoints gated by the feature_schedule_enabled flag.
"""
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse

from app.dependencies import DbSession, ReadDbSession, require_role, require_feature
from app.rate_limit import limiter, dynamic_limit
from app.models.user import User, UserRole
from app.schemas.schedule import (
    ScheduleItemCreate,
    ScheduleItemUpdate,
    ScheduleItemResponse,
    ScheduleDayGroup,
)
from app.services import schedule as schedule_service

router = APIRouter()

_feature_guard = Depends(require_feature("feature_schedule_enabled"))


# ── List schedule grouped by date (public) ────────────────

@router.get(
    "/{event_id}/schedule",
    response_model=list[ScheduleDayGroup],
    dependencies=[_feature_guard],
)
async def list_schedule(event_id: int, db: ReadDbSession):
    return await schedule_service.list_schedule(db, event_id)


# ── Create single schedule item (organizer) ───────────────

@router.post(
    "/{event_id}/schedule",
    response_model=ScheduleItemResponse,
    status_code=201,
    dependencies=[_feature_guard],
)
async def create_schedule_item(
    event_id: int,
    body: ScheduleItemCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await schedule_service.create_item(db, event_id, body, current_user)


# ── Bulk create schedule items (organizer) ─────────────────

@router.post(
    "/{event_id}/schedule/bulk",
    response_model=list[ScheduleItemResponse],
    status_code=201,
    dependencies=[_feature_guard],
)
async def bulk_create_schedule(
    event_id: int,
    body: list[ScheduleItemCreate],
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await schedule_service.bulk_create(db, event_id, body, current_user)


# ── Update schedule item (organizer) ──────────────────────

@router.patch(
    "/{event_id}/schedule/{item_id}",
    response_model=ScheduleItemResponse,
    dependencies=[_feature_guard],
)
async def update_schedule_item(
    event_id: int,
    item_id: int,
    body: ScheduleItemUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await schedule_service.update_item(db, item_id, body, current_user)


# ── Delete schedule item (organizer) ──────────────────────

@router.delete(
    "/{event_id}/schedule/{item_id}",
    status_code=204,
    dependencies=[_feature_guard],
)
async def delete_schedule_item(
    event_id: int,
    item_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    await schedule_service.delete_item(db, item_id, current_user)


# ── Upload image for schedule item (organizer) ────────────

@router.post(
    "/{event_id}/schedule/{item_id}/upload-image",
    response_model=ScheduleItemResponse,
    dependencies=[_feature_guard],
)
@limiter.limit(dynamic_limit("file_upload", "10/minute"))
async def upload_schedule_image(
    request: Request,
    event_id: int,
    item_id: int,
    db: DbSession,
    file: UploadFile = File(...),
    caption: str | None = Form(None),
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Upload an image for a schedule item."""
    from pathlib import Path
    import uuid
    from app.services import event as event_service

    ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, f"Unsupported file type: {file.content_type}")

    MAX_SIZE = 5 * 1024 * 1024
    contents = await file.read()
    if len(contents) > MAX_SIZE:
        raise HTTPException(400, "Image file too large (max 5 MB)")

    item = await schedule_service._get_or_404(db, item_id)
    event = await event_service.get_or_404(db, item.event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise HTTPException(403, "Only the organizer can manage the schedule")

    old_url = item.image_url
    if old_url and old_url.startswith("/static/uploads/schedule/"):
        old_path = Path(__file__).resolve().parent.parent.parent.parent / old_url.lstrip("/")
        if old_path.exists():
            old_path.unlink(missing_ok=True)

    ext = Path(file.filename or "img.jpg").suffix.lower() or ".jpg"
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        ext = ".jpg"
    filename = f"{event_id}_{item_id}_{uuid.uuid4().hex[:8]}{ext}"

    upload_dir = Path(__file__).resolve().parent.parent.parent.parent / "static" / "uploads" / "schedule" / str(event_id)
    upload_dir.mkdir(parents=True, exist_ok=True)
    (upload_dir / filename).write_bytes(contents)

    item.image_url = f"/static/uploads/schedule/{event_id}/{filename}"
    if caption is not None:
        item.image_caption = caption
    await db.flush()
    await db.refresh(item)
    return schedule_service._item_to_response(item)


# ── Remove image from schedule item (organizer) ──────────

@router.delete(
    "/{event_id}/schedule/{item_id}/image",
    response_model=ScheduleItemResponse,
    dependencies=[_feature_guard],
)
async def delete_schedule_image(
    event_id: int,
    item_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Remove the image from a schedule item."""
    from pathlib import Path
    from app.services import event as event_service

    item = await schedule_service._get_or_404(db, item_id)
    event = await event_service.get_or_404(db, item.event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise HTTPException(403, "Only the organizer can manage the schedule")

    old_url = item.image_url
    if old_url and old_url.startswith("/static/uploads/schedule/"):
        old_path = Path(__file__).resolve().parent.parent.parent.parent / old_url.lstrip("/")
        if old_path.exists():
            old_path.unlink(missing_ok=True)

    item.image_url = None
    item.image_caption = None
    await db.flush()
    await db.refresh(item)
    return schedule_service._item_to_response(item)


# ── Export schedule as Excel .xlsx (public) ────────────────

@router.get(
    "/{event_id}/schedule/export",
    dependencies=[_feature_guard],
)
async def export_schedule(event_id: int, db: ReadDbSession):
    buf = await schedule_service.export_schedule_xlsx(db, event_id)
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename=schedule_event_{event_id}.xlsx"},
    )
