"""
Event Schedule API — CRUD + bulk create + Excel export.
All endpoints gated by the feature_schedule_enabled flag.
"""
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from app.dependencies import DbSession, require_role, require_feature
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
async def list_schedule(event_id: int, db: DbSession):
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


# ── Export schedule as Excel .xlsx (public) ────────────────

@router.get(
    "/{event_id}/schedule/export",
    dependencies=[_feature_guard],
)
async def export_schedule(event_id: int, db: DbSession):
    buf = await schedule_service.export_schedule_xlsx(db, event_id)
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename=schedule_event_{event_id}.xlsx"},
    )
