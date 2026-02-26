"""
Discount Strategies: CRUD for reusable discount templates + attach/detach to events.
"""
from fastapi import APIRouter, Depends

from app.dependencies import DbSession, ReadDbSession, require_role
from app.models.user import User, UserRole
from app.schemas.discount_strategy import (
    DiscountStrategyCreate,
    DiscountStrategyResponse,
    DiscountStrategyUpdate,
)
from app.services import discount_strategy as ds_service

router = APIRouter()


@router.get("", response_model=list[DiscountStrategyResponse])
async def list_strategies(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List the current organizer's discount strategies."""
    return await ds_service.list_strategies(db, organizer_id=current_user.id)


@router.post("", response_model=DiscountStrategyResponse, status_code=201)
async def create_strategy(
    body: DiscountStrategyCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await ds_service.create_strategy(
        db, user=current_user,
        name=body.name, discount_type=body.discount_type,
        value=body.value, target=body.target,
    )


@router.get("/{strategy_id}", response_model=DiscountStrategyResponse)
async def get_strategy(
    strategy_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await ds_service.get_or_404(db, strategy_id)


@router.patch("/{strategy_id}", response_model=DiscountStrategyResponse)
async def update_strategy(
    strategy_id: int,
    body: DiscountStrategyUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    strategy = await ds_service.get_or_404(db, strategy_id)
    return await ds_service.update_strategy(
        db, strategy=strategy, user=current_user,
        name=body.name, discount_type=body.discount_type,
        value=body.value, target=body.target,
    )


@router.delete("/{strategy_id}", status_code=204)
async def delete_strategy(
    strategy_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    strategy = await ds_service.get_or_404(db, strategy_id)
    await ds_service.delete_strategy(db, strategy=strategy, user=current_user)
