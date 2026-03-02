"""
Event discounts: list, create, delete; compute_event_discounts_for_user.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import EventDiscount
from app.models.user import User
from app.core.exceptions import ForbiddenError, ConflictError, NotFoundError
from app.repositories.event_repo import event_repo

from app.services.event.crud import get_or_404
from app.services.event.permissions import user_can_edit_event


async def list_event_discounts(db: AsyncSession, *, event_id: int) -> list[EventDiscount]:
    return await event_repo.list_event_discounts(db, event_id)


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
    return await event_repo.create_event_discount(db, disc)


async def delete_event_discount(db: AsyncSession, *, event_id: int, discount_id: int, user: User) -> None:
    event = await get_or_404(db, event_id)
    if not await user_can_edit_event(db, event, user):
        raise ForbiddenError("Only event organizer or admin can manage discounts")
    disc = await event_repo.get_event_discount(db, event_id, discount_id)
    if not disc:
        raise NotFoundError("Discount", discount_id)
    await event_repo.delete_event_discount(db, disc)


# ===================================
# Customer discounts (what discount a specific customer gets)
# ===================================


async def compute_event_discounts_for_user(
    db: AsyncSession, *, event_id: int, user_id: int,
) -> list[dict]:
    """Return all applicable discount rules for a user (inline + auto-applied linked strategies + claimed strategies)."""
    event = await get_or_404(db, event_id)
    inline_discounts = await event_repo.list_event_discounts(db, event_id)

    # Linked strategies with auto_apply info
    links = await event_repo.get_discount_strategy_links(db, event_id)

    # Claims by this user
    link_ids = [l.id for l in links]
    claimed_ids = await event_repo.get_claimed_link_ids(db, user_id, link_ids) if links else set()

    # Check if user has pledged
    total_pledged = await event_repo.get_user_pledged_total(db, event_id, user_id)
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
    # Linked DiscountStrategy rules -- only auto-apply or claimed
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


# ===================================
# Organizer-Customer History
# ===================================
