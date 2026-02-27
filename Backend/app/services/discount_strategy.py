"""
Discount strategy CRUD — reusable discount templates owned by organizers.

auto_apply flag on the link:
  True  → discount is automatically applied to every eligible customer
  False → customer must explicitly claim it from the event discount page
"""
from typing import Sequence

from sqlalchemy import select

from app.logger import get_logger
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.discount_strategy import (
    CustomerDiscountClaim,
    DiscountStrategy,
    EventDiscountStrategyLink,
)
from app.models.user import User

logger = get_logger("svc.discount")


async def list_strategies(db: AsyncSession, *, organizer_id: int) -> Sequence[DiscountStrategy]:
    q = (
        select(DiscountStrategy)
        .where(DiscountStrategy.organizer_id == organizer_id)
        .order_by(DiscountStrategy.created_at.desc())
    )
    return (await db.execute(q)).scalars().all()


async def get_or_404(db: AsyncSession, strategy_id: int) -> DiscountStrategy:
    q = select(DiscountStrategy).where(DiscountStrategy.id == strategy_id)
    s = (await db.execute(q)).scalar_one_or_none()
    if not s:
        raise NotFoundError("DiscountStrategy", strategy_id)
    return s


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
    db.add(s)
    await db.flush()
    await db.refresh(s)
    return s


async def update_strategy(
    db: AsyncSession, *, strategy: DiscountStrategy, user: User,
    name: str | None = None, discount_type: str | None = None,
    value: int | None = None, target: str | None = None,
) -> DiscountStrategy:
    if strategy.organizer_id != user.id and user.role.value != "admin":
        raise ForbiddenError("Only the owner or admin can update this strategy")
    if name is not None:
        strategy.name = name
    if discount_type is not None or value is not None or target is not None:
        dt = discount_type or strategy.discount_type
        v = value if value is not None else strategy.value
        t = target or strategy.target
        logger.debug("Update discount strategy params", extra={"strategy_id": strategy.id, "discount_type": dt, "value": v, "target": t})
        _validate(dt, v, t)
        strategy.discount_type = dt
        strategy.value = v
        strategy.target = t
    await db.flush()
    await db.refresh(strategy)
    return strategy


async def delete_strategy(db: AsyncSession, *, strategy: DiscountStrategy, user: User) -> None:
    if strategy.organizer_id != user.id and user.role.value != "admin":
        raise ForbiddenError("Only the owner or admin can delete this strategy")
    await db.delete(strategy)
    await db.flush()


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
    existing = (
        await db.execute(
            select(EventDiscountStrategyLink).where(
                EventDiscountStrategyLink.event_id == event_id,
                EventDiscountStrategyLink.discount_strategy_id == strategy_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        raise ConflictError("Strategy already attached to this event")
    link = EventDiscountStrategyLink(
        event_id=event_id, discount_strategy_id=strategy_id, auto_apply=auto_apply,
    )
    db.add(link)
    await db.flush()
    await db.refresh(link)
    return link


async def detach_from_event(db: AsyncSession, *, event_id: int, strategy_id: int, user: User) -> None:
    """Unlink a discount strategy from an event."""
    q = select(EventDiscountStrategyLink).where(
        EventDiscountStrategyLink.event_id == event_id,
        EventDiscountStrategyLink.discount_strategy_id == strategy_id,
    )
    link = (await db.execute(q)).scalar_one_or_none()
    if not link:
        raise NotFoundError("Link", f"event={event_id}, strategy={strategy_id}")
    await db.delete(link)
    await db.flush()


async def list_event_strategies(db: AsyncSession, *, event_id: int) -> list[dict]:
    """Return all discount strategies attached to an event, with auto_apply flag."""
    q = (
        select(EventDiscountStrategyLink)
        .options(selectinload(EventDiscountStrategyLink.strategy))
        .where(EventDiscountStrategyLink.event_id == event_id)
        .order_by(EventDiscountStrategyLink.id)
    )
    links = list((await db.execute(q)).scalars().all())
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
    q = (
        select(EventDiscountStrategyLink)
        .options(selectinload(EventDiscountStrategyLink.strategy))
        .where(
            EventDiscountStrategyLink.event_id == event_id,
            EventDiscountStrategyLink.auto_apply == False,  # noqa: E712
        )
    )
    links = list((await db.execute(q)).scalars().all())
    # Which ones has user already claimed?
    claimed_q = select(CustomerDiscountClaim.link_id).where(
        CustomerDiscountClaim.user_id == user_id,
        CustomerDiscountClaim.link_id.in_([l.id for l in links]) if links else False,
    )
    claimed_ids = set((await db.execute(claimed_q)).scalars().all()) if links else set()

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
    link = (
        await db.execute(
            select(EventDiscountStrategyLink).where(EventDiscountStrategyLink.id == link_id)
        )
    ).scalar_one_or_none()
    if not link:
        raise NotFoundError("DiscountLink", link_id)
    if link.auto_apply:
        raise ConflictError("This discount is already auto-applied")
    existing = (
        await db.execute(
            select(CustomerDiscountClaim).where(
                CustomerDiscountClaim.link_id == link_id,
                CustomerDiscountClaim.user_id == user_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        raise ConflictError("Discount already claimed")
    claim = CustomerDiscountClaim(link_id=link_id, user_id=user_id)
    db.add(claim)
    await db.flush()
    await db.refresh(claim)
    return claim


async def unclaim_discount(db: AsyncSession, *, link_id: int, user_id: int) -> None:
    """Customer removes a previously claimed discount."""
    q = select(CustomerDiscountClaim).where(
        CustomerDiscountClaim.link_id == link_id,
        CustomerDiscountClaim.user_id == user_id,
    )
    claim = (await db.execute(q)).scalar_one_or_none()
    if not claim:
        raise NotFoundError("Claim", f"link={link_id}, user={user_id}")
    await db.delete(claim)
    await db.flush()


async def user_has_claimed(db: AsyncSession, *, link_id: int, user_id: int) -> bool:
    q = select(CustomerDiscountClaim.id).where(
        CustomerDiscountClaim.link_id == link_id,
        CustomerDiscountClaim.user_id == user_id,
    )
    return (await db.execute(q)).scalar_one_or_none() is not None


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
