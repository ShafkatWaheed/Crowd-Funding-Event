"""Sponsorship categories (per-event)."""
from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature
from app.models.user import UserRole
from app.schemas.sponsor import CategoryCreate, CategoryUpdate, CategoryResponse
from app.services import sponsor as sponsor_svc

from app.api.v1.sponsors._helpers import _category_to_response

router = APIRouter(dependencies=[Depends(require_feature("feature_sponsors_enabled"))])


@router.get("/events/{event_id}/sponsorships")
async def list_categories(
    event_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    if current_user.role not in (UserRole.sponsor, UserRole.organizer, UserRole.admin):
        raise HTTPException(status_code=403, detail="Sponsorship categories are not visible to customers")
    cats = await sponsor_svc.list_categories(db, event_id)
    prereq_counts = await sponsor_svc.get_prereq_counts(db, [c.id for c in cats])
    result = []
    for c in cats:
        count, amounts = await sponsor_svc.get_bid_stats(db, c.id)
        my_count = await sponsor_svc.get_my_bid_count(db, c.id, current_user.id)
        my_bids = await sponsor_svc.get_my_bids(db, c.id, current_user.id)
        result.append(_category_to_response(
            c,
            bid_count=count,
            bid_amounts=amounts,
            my_bid_count=my_count,
            my_bids=my_bids,
            prereq_count=prereq_counts.get(c.id, 0),
        ))
    return result


@router.post(
    "/events/{event_id}/sponsorships",
    response_model=CategoryResponse,
    status_code=201,
)
async def create_category(
    event_id: int,
    data: CategoryCreate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.create_category(db, event_id, current_user, data)
    return _category_to_response(cat)


@router.patch(
    "/events/{event_id}/sponsorships/{cat_id}",
    response_model=CategoryResponse,
)
async def update_category(
    event_id: int,
    cat_id: int,
    data: CategoryUpdate,
    db: DbSession,
    current_user: CurrentUser,
):
    cat = await sponsor_svc.update_category(db, cat_id, current_user, data)
    return _category_to_response(cat)


@router.delete("/events/{event_id}/sponsorships/{cat_id}", status_code=204)
async def delete_category(
    event_id: int,
    cat_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    await sponsor_svc.delete_category(db, cat_id, current_user)
