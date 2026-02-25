"""Sponsor category templates and template prerequisites."""
from fastapi import APIRouter, Depends, Form, HTTPException
from sqlalchemy import select

from app.dependencies import DbSession, CurrentUser, require_feature
from app.models.user import UserRole
from app.models.prerequisite import CategoryPrerequisite
from app.models.sponsor import SponsorshipCategory
from app.schemas.sponsor import CategoryCreate, CategoryUpdate
from app.services import sponsor as sponsor_svc

from app.api.v1.sponsors._helpers import _template_to_response

router = APIRouter(dependencies=[Depends(require_feature("feature_sponsors_enabled"))])


@router.get("/me/sponsor-category-templates")
async def list_templates(db: DbSession, current_user: CurrentUser):
    templates = await sponsor_svc.list_templates(db, current_user)
    return [_template_to_response(t) for t in templates]


@router.post("/me/sponsor-category-templates", status_code=201)
async def create_template(
    data: CategoryCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.create_template(db, current_user, data)
    await db.commit()
    await db.refresh(cat)
    return _template_to_response(cat)


@router.patch("/me/sponsor-category-templates/{template_id}")
async def update_template(
    template_id: int,
    data: CategoryUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.update_template(db, template_id, current_user, data)
    await db.commit()
    await db.refresh(cat)
    return _template_to_response(cat)


@router.delete("/me/sponsor-category-templates/{template_id}", status_code=204)
async def delete_template(
    template_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    await sponsor_svc.delete_template(db, template_id, current_user)
    await db.commit()


@router.post("/events/{event_id}/sponsorships/from-template/{template_id}", status_code=201)
async def copy_template_to_event(
    event_id: int,
    template_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.copy_template_to_event(db, template_id, event_id, current_user)
    await db.commit()
    await db.refresh(cat)
    return {
        "id": cat.id,
        "event_id": cat.event_id,
        "name": cat.name,
        "description": cat.description,
        "total_spots": cat.total_spots,
        "min_bid_cents": cat.min_bid_cents,
    }


@router.get("/me/sponsor-category-templates/{template_id}/prerequisites")
async def list_template_prerequisites(
    template_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    q = select(CategoryPrerequisite).where(CategoryPrerequisite.category_id == template_id)
    items = (await db.execute(q)).scalars().all()
    return [
        {"id": p.id, "name": p.name, "description": p.description, "is_required": p.is_required, "requires_document": p.requires_document}
        for p in items
    ]


@router.post("/me/sponsor-category-templates/{template_id}/prerequisites", status_code=201)
async def create_template_prerequisite(
    template_id: int,
    name: str = Form(...),
    description: str | None = Form(None),
    is_required: bool = Form(True),
    requires_document: bool = Form(False),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    cat = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != current_user.id and current_user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")
    prereq = CategoryPrerequisite(
        category_id=template_id,
        name=name,
        description=description,
        is_required=is_required,
        requires_document=requires_document,
    )
    db.add(prereq)
    await db.flush()
    await db.refresh(prereq)
    await db.commit()
    return {"id": prereq.id, "name": prereq.name, "description": prereq.description, "is_required": prereq.is_required}


@router.delete("/me/sponsor-category-templates/{template_id}/prerequisites/{prereq_id}", status_code=204)
async def delete_template_prerequisite(
    template_id: int,
    prereq_id: int,
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    cat = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != current_user.id and current_user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")
    prereq = (await db.execute(
        select(CategoryPrerequisite).where(
            CategoryPrerequisite.id == prereq_id,
            CategoryPrerequisite.category_id == template_id,
        )
    )).scalar_one_or_none()
    if not prereq:
        raise HTTPException(status_code=404, detail="Prerequisite not found")
    await db.delete(prereq)
    await db.commit()
