"""
Discount strategy CRUD — reusable discount templates owned by organizers.

auto_apply flag on the link:
  True  → discount is automatically applied to every eligible customer
  False → customer must explicitly claim it from the event discount page
"""
from typing import Sequence

from app.logger import get_logger
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.discount_strategy import (
    CustomerDiscountClaim,
    DiscountStrategy,
    EventDiscountStrategyLink,
)
from app.models.user import User
from app.repositories.discount_repo import discount_repo

logger = get_logger("svc.discount")


async def list_strategies(db: AsyncSession, *, organizer_id: int) -> Sequence[DiscountStrategy]:
    return await discount_repo.list_by_organizer(db, organizer_id)


async def get_or_404(db: AsyncSession, strategy_id: int) -> DiscountStrategy:
    return await discount_repo.get_or_404(db, strategy_id, "DiscountStrategy")


async def create_strategy(
    db: AsyncSession, *, user: User,
    name: str, discount_type: str, value: int, target: str = "all",
) -> DiscountStrategy:
    logger.debug("Create discount strategy", extra={"discount_type": discount_type, "value": value, "target": target})
    _validate(discount_type, value, target)
    s = DiscountStrategy(
        organizer_id=user.id, name=name,
        discount_type=discount_type, value=value, target=target,
    )
    return await discount_repo.create(db, s)


async def update_strategy(
    db: AsyncSession, *, strategy: DiscountStrategy, user: User,
    name: str | None = None, discount_type: str | None = None,
    value: int | None = None, target: str | None = None,
) -> DiscountStrategy:
    if strategy.organizer_id != user.id and user.role.value != "admin":
        raise ForbiddenError("Only the owner or admin can update this strategy")
    data = {}
    if name is not None:
        data["name"] = name
    if discount_type is not None or value is not None or target is not None:
        dt = discount_type or strategy.discount_type
        v = value if value is not None else strategy.value
        t = target or strategy.target
        logger.debug("Update discount strategy params", extra={"strategy_id": strategy.id, "discount_type": dt, "value": v, "target": t})
        _validate(dt, v, t)
        data["discount_type"] = dt
        data["value"] = v
        data["target"] = t
    return await discount_repo.update_fields(db, strategy, data)


async def delete_strategy(db: AsyncSession, *, strategy: DiscountStrategy, user: User) -> None:
    if strategy.organizer_id != user.id and user.role.value != "admin":
        raise ForbiddenError("Only the owner or admin can delete this strategy")
    await discount_repo.delete_strategy(db, strategy)


# ─── Attach / Detach from events ───


async def attach_to_event(
    db: AsyncSession,
    *,
    event_id: int,
    strategy_id: int,
    user: User,
    auto_apply: bool = True,
) -> EventDiscountStrategyLink:
    """Link a discount strategy to an event. auto_apply=True → applied to all, False → customer must claim."""
    strategy = await get_or_404(db, strategy_id)
    if strategy.organizer_id != user.id and user.role.value != "admin":
        raise ForbiddenError("You don't own this strategy")
    existing = await discount_repo.get_link(db, event_id, strategy_id)
    if existing:
        raise ConflictError("Strategy already attached to this event")
    link = EventDiscountStrategyLink(
        event_id=event_id, discount_strategy_id=strategy_id, auto_apply=auto_apply,
    )
    return await discount_repo.create_link(db, link)


async def detach_from_event(db: AsyncSession, *, event_id: int, strategy_id: int, user: User) -> None:
    """Unlink a discount strategy from an event."""
    link = await discount_repo.get_link(db, event_id, strategy_id)
    if not link:
        raise NotFoundError("Link", f"event={event_id}, strategy={strategy_id}")
    await discount_repo.delete_link(db, link)


async def list_event_strategies(db: AsyncSession, *, event_id: int) -> list[dict]:
    """Return all discount strategies attached to an event, with auto_apply flag."""
    links = await discount_repo.list_event_links(db, event_id)
    results = []
    for link in links:
        s = link.strategy
        results.append({
            "id": s.id,
            "name": s.name,
            "discount_type": s.discount_type,
            "value": s.value,
            "target": s.target,
            "auto_apply": link.auto_apply,
        })
    return results


# ─── Customer discount claims ───


async def list_claimable_discounts(
    db: AsyncSession, *, event_id: int, user_id: int,
) -> list[dict]:
    """Return non-auto-apply discounts on this event that the customer can claim or has claimed."""
    links = await discount_repo.list_claimable_links(db, event_id)
    claimed_ids = await discount_repo.list_claimed_link_ids(
        db, user_id, [l.id for l in links]
    )

    results = []
    for link in links:
        s = link.strategy
        results.append({
            "link_id": link.id,
            "strategy_id": s.id,
            "name": s.name,
            "discount_type": s.discount_type,
            "value": s.value,
            "target": s.target,
            "claimed": link.id in claimed_ids,
        })
    return results


async def claim_discount(db: AsyncSession, *, link_id: int, user_id: int) -> CustomerDiscountClaim:
    logger.debug("Claim discount", extra={"link_id": link_id, "user_id": user_id})
    link = await discount_repo.get_link_by_id(db, link_id)
    if not link:
        raise NotFoundError("DiscountLink", link_id)
    if link.auto_apply:
        raise ConflictError("This discount is already auto-applied")
    existing = await discount_repo.get_claim(db, link_id, user_id)
    if existing:
        raise ConflictError("Discount already claimed")
    claim = CustomerDiscountClaim(link_id=link_id, user_id=user_id)
    return await discount_repo.create_claim(db, claim)


async def unclaim_discount(db: AsyncSession, *, link_id: int, user_id: int) -> None:
    """Customer removes a previously claimed discount."""
    claim = await discount_repo.get_claim(db, link_id, user_id)
    if not claim:
        raise NotFoundError("Claim", f"link={link_id}, user={user_id}")
    await discount_repo.delete_claim(db, claim)


async def user_has_claimed(db: AsyncSession, *, link_id: int, user_id: int) -> bool:
    return await discount_repo.user_has_claimed(db, link_id, user_id)


# ─── Validation ───


def _validate(discount_type: str, value: int, target: str) -> None:
    if discount_type not in ("pledge_percent", "ticket_percent"):
        raise ConflictError("discount_type must be 'pledge_percent' or 'ticket_percent'")
    if target not in ("all", "pledgers", "non_pledgers"):
        raise ConflictError("target must be 'all', 'pledgers', or 'non_pledgers'")
    if discount_type == "pledge_percent" and target == "non_pledgers":
        raise ConflictError("'% of Pledge' discount cannot target non-pledgers")
    if not (0 < value <= 100):
        raise ConflictError("Percent value must be 1-100")
