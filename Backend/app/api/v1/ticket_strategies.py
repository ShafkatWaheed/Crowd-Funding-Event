"""
Ticket Strategy CRUD endpoints (reusable ticketing templates, like venues).
"""
from fastapi import APIRouter, Depends

from app.dependencies import DbSession, ReadDbSession, require_role
from app.models.user import User, UserRole
from app.schemas.ticket_strategy import (
    TicketStrategyCreate,
    TicketStrategyResponse,
    TicketStrategyUpdate,
)
from app.services import ticket_strategy as strategy_service

router = APIRouter()


@router.get("", response_model=list[TicketStrategyResponse])
async def list_my_strategies(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List ticket strategies owned by the current organizer."""
    strategies = await strategy_service.list_strategies(db, organizer_id=current_user.id)
    return [TicketStrategyResponse.model_validate(s) for s in strategies]


@router.post("", response_model=TicketStrategyResponse)
async def create_strategy(
    body: TicketStrategyCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create a new ticket strategy with tiers."""
    if not body.tiers:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="At least one tier is required")
    strategy = await strategy_service.create(
        db,
        organizer_id=current_user.id,
        name=body.name,
        tiers=[t.model_dump() for t in body.tiers],
    )
    return TicketStrategyResponse.model_validate(strategy)


@router.get("/{strategy_id}", response_model=TicketStrategyResponse)
async def get_strategy(
    strategy_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Get a ticket strategy by ID."""
    strategy = await strategy_service.get_or_404(db, strategy_id)
    return TicketStrategyResponse.model_validate(strategy)


@router.patch("/{strategy_id}", response_model=TicketStrategyResponse)
async def update_strategy(
    strategy_id: int,
    body: TicketStrategyUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update a ticket strategy (name and/or replace tiers)."""
    strategy = await strategy_service.get_or_404(db, strategy_id)
    tiers_data = [t.model_dump() for t in body.tiers] if body.tiers is not None else None
    strategy = await strategy_service.update(
        db, strategy, current_user,
        name=body.name,
        tiers=tiers_data,
    )
    return TicketStrategyResponse.model_validate(strategy)


@router.delete("/{strategy_id}")
async def delete_strategy(
    strategy_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete a ticket strategy."""
    strategy = await strategy_service.get_or_404(db, strategy_id)
    await strategy_service.delete(db, strategy, current_user)
    return {"ok": True}
