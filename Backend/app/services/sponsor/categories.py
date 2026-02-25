"""Sponsorship categories and templates, plus bid stats helpers."""
from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.models.event import Event
from app.models.sponsor import SponsorshipCategory, SponsorBid, BidStatus
from app.schemas.sponsor import CategoryCreate, CategoryUpdate


async def _require_organizer(db: AsyncSession, event_id: int, user: User) -> Event:
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Only the organizer can manage sponsorship categories")
    return event


async def _get_category(db: AsyncSession, cat_id: int) -> SponsorshipCategory:
    cat = (await db.execute(
        select(SponsorshipCategory).where(SponsorshipCategory.id == cat_id)
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    return cat


async def list_categories(db: AsyncSession, event_id: int) -> list[SponsorshipCategory]:
    q = (
        select(SponsorshipCategory)
        .where(SponsorshipCategory.event_id == event_id)
        .order_by(SponsorshipCategory.sort_order, SponsorshipCategory.id)
    )
    return list((await db.execute(q)).scalars().all())


async def get_prereq_counts(db: AsyncSession, category_ids: list[int]) -> dict[int, int]:
    if not category_ids:
        return {}
    from app.models.prerequisite import CategoryPrerequisite
    q = (
        select(CategoryPrerequisite.category_id, func.count(CategoryPrerequisite.id))
        .where(CategoryPrerequisite.category_id.in_(category_ids))
        .group_by(CategoryPrerequisite.category_id)
    )
    rows = (await db.execute(q)).all()
    return {cat_id: cnt for cat_id, cnt in rows}


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
    db.add(cat)
    await db.flush()
    await db.refresh(cat)
    return cat


async def update_category(
    db: AsyncSession, cat_id: int, user: User, data: CategoryUpdate
) -> SponsorshipCategory:
    cat = (await db.execute(
        select(SponsorshipCategory).where(SponsorshipCategory.id == cat_id)
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await _require_organizer(db, cat.event_id, user)

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(cat, field, value)
    await db.flush()
    await db.refresh(cat)
    return cat


async def delete_category(db: AsyncSession, cat_id: int, user: User) -> None:
    cat = (await db.execute(
        select(SponsorshipCategory).where(SponsorshipCategory.id == cat_id)
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await _require_organizer(db, cat.event_id, user)
    await db.delete(cat)
    await db.flush()


async def list_templates(db: AsyncSession, user: User) -> list[SponsorshipCategory]:
    q = (
        select(SponsorshipCategory)
        .where(SponsorshipCategory.is_template == True, SponsorshipCategory.organizer_id == user.id)
        .order_by(SponsorshipCategory.name)
    )
    return list((await db.execute(q)).scalars().all())


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
    db.add(cat)
    await db.flush()
    await db.refresh(cat)
    return cat


async def update_template(db: AsyncSession, template_id: int, user: User, data: CategoryUpdate) -> SponsorshipCategory:
    cat = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(cat, field, value)
    await db.flush()
    await db.refresh(cat)
    return cat


async def delete_template(db: AsyncSession, template_id: int, user: User) -> None:
    cat = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Template not found")
    if cat.organizer_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not your template")
    await db.delete(cat)
    await db.flush()


async def copy_template_to_event(
    db: AsyncSession, template_id: int, event_id: int, user: User
) -> SponsorshipCategory:
    """Copy a template category (and its prerequisites) into an event-scoped category."""
    template = (await db.execute(
        select(SponsorshipCategory).where(
            SponsorshipCategory.id == template_id,
            SponsorshipCategory.is_template == True,
        )
    )).scalar_one_or_none()
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
    db.add(cat)
    await db.flush()
    await db.refresh(cat)

    from app.models.prerequisite import CategoryPrerequisite
    prereqs = (await db.execute(
        select(CategoryPrerequisite).where(CategoryPrerequisite.category_id == template_id)
    )).scalars().all()

    for p in prereqs:
        new_prereq = CategoryPrerequisite(
            category_id=cat.id,
            name=p.name,
            description=p.description,
            is_required=p.is_required,
        )
        db.add(new_prereq)

    await db.flush()
    await db.refresh(cat)
    return cat


async def get_bid_stats(db: AsyncSession, cat_id: int) -> tuple[int, list[int]]:
    all_q = select(SponsorBid).where(
        SponsorBid.category_id == cat_id,
        SponsorBid.status.in_([BidStatus.pending, BidStatus.accepted, BidStatus.paid]),
    )
    all_bids = list((await db.execute(all_q)).scalars().all())
    pending_amounts = [b.amount_cents for b in all_bids if b.status == BidStatus.pending]
    return len(all_bids), pending_amounts


async def get_my_bid_count(db: AsyncSession, cat_id: int, user_id: int) -> int:
    active_statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
    q = select(SponsorBid).where(
        SponsorBid.category_id == cat_id,
        SponsorBid.sponsor_user_id == user_id,
        SponsorBid.status.in_(active_statuses),
    )
    bids = list((await db.execute(q)).scalars().all())
    return len(bids)


async def get_my_bids(db: AsyncSession, cat_id: int, user_id: int) -> list[dict]:
    q = select(SponsorBid).where(
        SponsorBid.category_id == cat_id,
        SponsorBid.sponsor_user_id == user_id,
        SponsorBid.status != BidStatus.withdrawn,
    ).order_by(SponsorBid.id.desc())
    bids = list((await db.execute(q)).scalars().all())
    return [
        {"id": b.id, "amount_cents": b.amount_cents, "status": b.status.value}
        for b in bids
    ]
