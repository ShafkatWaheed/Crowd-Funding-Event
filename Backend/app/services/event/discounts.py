"""
Event discounts: list, create, delete; compute_event_discounts_for_user.
"""
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import EventDiscount
from app.models.user import User
from app.models.funding import Funding, FundingStatus
from app.models.discount_strategy import EventDiscountStrategyLink
from app.core.exceptions import ForbiddenError, ConflictError, NotFoundError

from app.services.event.crud import get_or_404
from app.services.event.permissions import user_can_edit_event


async def list_event_discounts(db: AsyncSession, *, event_id: int) -> list[EventDiscount]:
    q = select(EventDiscount).where(EventDiscount.event_id == event_id).order_by(EventDiscount.id)
    return list((await db.execute(q)).scalars().all())


async def create_event_discount(
    db: AsyncSession, *, event_id: int, user: User,
    name: str, discount_type: str, value: int, target: str = "all",
) -> EventDiscount:
    event = await get_or_404(db, event_id)
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("Only event organizer or admin can manage discounts")
    if discount_type not in ("pledge_percent", "ticket_percent"):
        raise ConflictError("discount_type must be 'pledge_percent' or 'ticket_percent'")
    if target not in ("all", "pledgers", "non_pledgers"):
        raise ConflictError("target must be 'all', 'pledgers', or 'non_pledgers'")
    if discount_type == "pledge_percent" and target == "non_pledgers":
        raise ConflictError("'% of Pledge' discount cannot target non-pledgers")
    if not (0 < value <= 100):
        raise ConflictError("Percent value must be 1-100")
    disc = EventDiscount(
        event_id=event_id, name=name, discount_type=discount_type, value=value, target=target,
    )
    db.add(disc)
    await db.flush()
    await db.refresh(disc)
    return disc


async def delete_event_discount(db: AsyncSession, *, event_id: int, discount_id: int, user: User) -> None:
    event = await get_or_404(db, event_id)
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("Only event organizer or admin can manage discounts")
    q = select(EventDiscount).where(EventDiscount.id == discount_id, EventDiscount.event_id == event_id)
    disc = (await db.execute(q)).scalar_one_or_none()
    if not disc:
        raise NotFoundError("Discount", discount_id)
    await db.delete(disc)
    await db.flush()


# ═══════════════════════════════════════════
# Customer discounts (what discount a specific customer gets)
# ═══════════════════════════════════════════


async def compute_event_discounts_for_user(
    db: AsyncSession, *, event_id: int, user_id: int,
) -> list[dict]:
    """Return all applicable discount rules for a user (inline + auto-applied linked strategies + claimed strategies)."""
    from app.models.discount_strategy import CustomerDiscountClaim
    from sqlalchemy.orm import selectinload as _sload

    event = await get_or_404(db, event_id)
    inline_discounts = await list_event_discounts(db, event_id=event_id)

    # Linked strategies with auto_apply info
    link_q = (
        select(EventDiscountStrategyLink)
        .options(_sload(EventDiscountStrategyLink.strategy))
        .where(EventDiscountStrategyLink.event_id == event_id)
    )
    links = list((await db.execute(link_q)).scalars().all())

    # Claims by this user
    claim_q = select(CustomerDiscountClaim.link_id).where(
        CustomerDiscountClaim.user_id == user_id,
        CustomerDiscountClaim.link_id.in_([l.id for l in links]) if links else False,
    )
    claimed_ids = set((await db.execute(claim_q)).scalars().all()) if links else set()

    # Check if user has pledged
    pledge_q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.user_id == user_id,
        Funding.status == FundingStatus.pledged,
    )
    total_pledged = int((await db.execute(pledge_q)).scalar_one())
    has_pledged = total_pledged > 0

    results = []
    # Inline EventDiscount rules
    for d in inline_discounts:
        if d.target == "pledgers" and not has_pledged:
            continue
        if d.target == "non_pledgers" and has_pledged:
            continue
        results.append({
            "id": d.id,
            "name": d.name,
            "discount_type": d.discount_type,
            "value": d.value,
            "target": d.target,
            "total_pledged_cents": total_pledged if d.discount_type == "pledge_percent" else 0,
        })
    # Linked DiscountStrategy rules — only auto-apply or claimed
    for link in links:
        if not link.auto_apply and link.id not in claimed_ids:
            continue
        s = link.strategy
        if s.target == "pledgers" and not has_pledged:
            continue
        if s.target == "non_pledgers" and has_pledged:
            continue
        results.append({
            "id": s.id,
            "name": s.name,
            "discount_type": s.discount_type,
            "value": s.value,
            "target": s.target,
            "total_pledged_cents": total_pledged if s.discount_type == "pledge_percent" else 0,
            "source": "strategy",
            "auto_apply": link.auto_apply,
            "claimed": link.id in claimed_ids,
        })
    return results


# ═══════════════════════════════════════════
# Organizer–Customer History
# ═══════════════════════════════════════════

