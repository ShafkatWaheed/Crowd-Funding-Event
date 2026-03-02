"""Sponsorship categories and templates, plus bid stats helpers."""
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.event import Event
from app.models.sponsor import SponsorshipCategory, BidStatus
from app.models.prerequisite import CategoryPrerequisite
from app.schemas.sponsor import CategoryCreate, CategoryUpdate
from app.repositories.sponsor_repo import sponsor_repo


async def _require_organizer(db: AsyncSession, event_id: int, user: User) -> Event:
    event = await sponsor_repo.get_event(db, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Only the organizer can manage sponsorship categories")
    return event


async def _get_category(db: AsyncSession, cat_id: int) -> SponsorshipCategory:
    cat = await sponsor_repo.get_category(db, cat_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    return cat


async def list_categories(db: AsyncSession, event_id: int) -> list[SponsorshipCategory]:
    return await sponsor_repo.list_categories(db, event_id)


async def get_prereq_counts(db: AsyncSession, category_ids: list[int]) -> dict[int, int]:
    return await sponsor_repo.get_prereq_counts(db, category_ids)


async def create_category(
    db: AsyncSession, event_id: int, user: User, data: CategoryCreate
) -> SponsorshipCategory:
    await _require_organizer(db, event_id, user)
    cat = SponsorshipCategory(
        event_id=event_id,
        name=data.name,
        description=data.description,
        image_url=data.image_url,
        total_spots=data.total_spots,
        min_bid_cents=data.min_bid_cents,
        sort_order=data.sort_order,
    )
    return await sponsor_repo.create_category(db, cat)


async def update_category(
    db: AsyncSession, cat_id: int, user: User, data: CategoryUpdate
) -> SponsorshipCategory:
    cat = await sponsor_repo.get_category(db, cat_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await _require_organizer(db, cat.event_id, user)

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(cat, field, value)
    return await sponsor_repo.update_category(db, cat)


async def delete_category(db: AsyncSession, cat_id: int, user: User) -> None:
    cat = await sponsor_repo.get_category(db, cat_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await _require_organizer(db, cat.event_id, user)
    await sponsor_repo.delete_category(db, cat)


async def list_templates(db: AsyncSession, user: User) -> list[SponsorshipCategory]:
    return await sponsor_repo.list_templates(db, user.id)


async def create_template(db: AsyncSession, user: User, data: CategoryCreate) -> SponsorshipCategory:
    cat = SponsorshipCategory(
        event_id=None,
        organizer_id=user.id,
        is_template=True,
        name=data.name,
        description=data.description,
        image_url=data.image_url,
        total_spots=data.total_spots,
        min_bid_cents=data.min_bid_cents,
        sort_order=data.sort_order,
    )
    return await sponsor_repo.create_template(db, cat)


async def update_template(db: AsyncSession, template_id: int, user: User, data: CategoryUpdate) -> SponsorshipCategory:
    cat = await sponsor_repo.get_template(db, template_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(cat, field, value)
    return await sponsor_repo.update_template(db, cat)


async def delete_template(db: AsyncSession, template_id: int, user: User) -> None:
    cat = await sponsor_repo.get_template(db, template_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")
    await sponsor_repo.delete_template(db, cat)


async def copy_template_to_event(
    db: AsyncSession, template_id: int, event_id: int, user: User
) -> SponsorshipCategory:
    """Copy a template category (and its prerequisites) into an event-scoped category."""
    template = await sponsor_repo.get_template(db, template_id)
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    await _require_organizer(db, event_id, user)

    cat = SponsorshipCategory(
        event_id=event_id,
        organizer_id=user.id,
        is_template=False,
        name=template.name,
        description=template.description,
        image_url=template.image_url,
        total_spots=template.total_spots,
        min_bid_cents=template.min_bid_cents,
        sort_order=template.sort_order,
    )
    cat = await sponsor_repo.create_category(db, cat)

    prereqs = await sponsor_repo.list_prerequisites(db, template_id)

    for p in prereqs:
        new_prereq = CategoryPrerequisite(
            category_id=cat.id,
            name=p.name,
            description=p.description,
            is_required=p.is_required,
        )
        await sponsor_repo.create_prerequisite(db, new_prereq)

    # Re-flush and refresh to pick up any new prerequisite relations
    cat = await sponsor_repo.update_category(db, cat)
    return cat


async def get_bid_stats(db: AsyncSession, cat_id: int) -> tuple[int, list[int]]:
    all_bids = await sponsor_repo.get_bid_stats(db, cat_id)
    pending_amounts = [b.amount_cents for b in all_bids if b.status == BidStatus.pending]
    return len(all_bids), pending_amounts


async def get_my_bid_count(db: AsyncSession, cat_id: int, user_id: int) -> int:
    active_statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
    bids = await sponsor_repo.count_active_bids_by_user(db, cat_id, user_id, active_statuses)
    return len(bids)


async def get_my_bids(db: AsyncSession, cat_id: int, user_id: int) -> list[dict]:
    bids = await sponsor_repo.get_my_bids(db, cat_id, user_id)
    return [
        {"id": b.id, "amount_cents": b.amount_cents, "status": b.status.value}
        for b in bids
    ]
