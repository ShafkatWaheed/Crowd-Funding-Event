"""
Event discounts: user discounts, rules CRUD, discount strategies, claimable discounts.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.dependencies import DbSession, ReadDbSession, require_role
from app.models.user import User, UserRole
from app.schemas import EventDiscountCreate, EventDiscountResponse, UserDiscountBody
from app.core.exceptions import ForbiddenError
from app.services import event as event_service
from app.services import ticket as ticket_service
from app.services import discount_strategy as ds_service

router = APIRouter()


class AttachDiscountBody(BaseModel):
    auto_apply: bool = True


@router.post("/{event_id}/discounts")
async def set_user_discount(
    event_id: int,
    body: UserDiscountBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    ued = await ticket_service.set_user_discount(
        db, event_id=event_id, target_user_id=body.user_id, current_user=current_user,
        discount_type=body.discount_type, value=body.value,
    )
    return {"id": ued.id, "event_id": ued.event_id, "user_id": ued.user_id, "discount_type": ued.discount_type, "value": ued.value}


@router.delete("/{event_id}/discounts/{user_id}")
async def remove_user_discount(
    event_id: int,
    user_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    await ticket_service.remove_user_discount(
        db, event_id=event_id, target_user_id=user_id, current_user=current_user,
    )
    return {"ok": True}


@router.get("/{event_id}/discounts/rules", response_model=list[EventDiscountResponse])
async def list_event_discounts(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_read_event_mgmt(db, event, current_user):
        raise ForbiddenError("You cannot view discounts for this event")
    return await event_service.list_event_discounts(db, event_id=event_id)


@router.post("/{event_id}/discounts/rules", response_model=EventDiscountResponse)
async def create_event_discount(
    event_id: int,
    body: EventDiscountCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await event_service.create_event_discount(
        db, event_id=event_id, user=current_user,
        name=body.name, discount_type=body.discount_type,
        value=body.value, target=body.target,
    )


@router.delete("/{event_id}/discounts/rules/{discount_id}")
async def delete_event_discount(
    event_id: int,
    discount_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    await event_service.delete_event_discount(db, event_id=event_id, discount_id=discount_id, user=current_user)
    return {"ok": True}


@router.get("/{event_id}/my-discounts")
async def get_my_discounts(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin, UserRole.sponsor)),
):
    return await event_service.compute_event_discounts_for_user(
        db, event_id=event_id, user_id=current_user.id,
    )


@router.get("/{event_id}/discount-strategies")
async def list_event_discount_strategies(
    event_id: int,
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    return await ds_service.list_event_strategies(db, event_id=event_id)


@router.post("/{event_id}/discount-strategies/{strategy_id}")
async def attach_discount_strategy(
    event_id: int,
    strategy_id: int,
    db: DbSession,
    body: AttachDiscountBody | None = None,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot modify this event")
    auto = body.auto_apply if body else True
    await ds_service.attach_to_event(
        db, event_id=event_id, strategy_id=strategy_id, user=current_user, auto_apply=auto,
    )
    return {"ok": True}


@router.delete("/{event_id}/discount-strategies/{strategy_id}")
async def detach_discount_strategy(
    event_id: int,
    strategy_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot modify this event")
    await ds_service.detach_from_event(db, event_id=event_id, strategy_id=strategy_id, user=current_user)
    return {"ok": True}


@router.get("/{event_id}/claimable-discounts")
async def list_claimable_discounts(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin, UserRole.sponsor)),
):
    return await ds_service.list_claimable_discounts(
        db, event_id=event_id, user_id=current_user.id,
    )


@router.post("/{event_id}/claim-discount/{link_id}")
async def claim_discount(
    event_id: int,
    link_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    claim = await ds_service.claim_discount(db, link_id=link_id, user_id=current_user.id)
    return {"ok": True, "claim_id": claim.id}


@router.delete("/{event_id}/claim-discount/{link_id}")
async def unclaim_discount(
    event_id: int,
    link_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    await ds_service.unclaim_discount(db, link_id=link_id, user_id=current_user.id)
    return {"ok": True}
