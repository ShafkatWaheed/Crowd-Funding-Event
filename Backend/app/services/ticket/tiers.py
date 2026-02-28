"""
Ticket tier CRUD and user discount (selective) management.
"""
from sqlalchemy import func, select

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Sequence

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.event import Event
from app.models.ticket import TicketSale, TicketTier, UserEventDiscount
from app.models.user import User
from app.services import event as event_service

logger = get_logger("svc.ticket.tiers")


async def _can_manage_event_tickets(db: AsyncSession, user: User, event: Event) -> bool:
    """True if admin, main organizer, or co-organizer (via event_service)."""
    return await event_service.user_can_edit_event(db, event, user)


async def list_tiers(db: AsyncSession, *, event_id: int) -> Sequence[TicketTier]:
    """List ticket tiers for an event (display_order, id)."""
    await event_service.get_or_404(db, event_id)
    q = (
        select(TicketTier)
        .where(TicketTier.event_id == event_id)
        .order_by(TicketTier.display_order.asc(), TicketTier.id.asc())
    )
    res = await db.execute(q)
    return list(res.scalars().all())


async def get_tier_or_404(db: AsyncSession, *, event_id: int, tier_id: int) -> TicketTier:
    q = select(TicketTier).where(
        TicketTier.id == tier_id,
        TicketTier.event_id == event_id,
    )
    res = await db.execute(q)
    tier = res.scalar_one_or_none()
    if not tier:
        raise NotFoundError("TicketTier", tier_id)
    return tier


async def _tier_has_sales(db: AsyncSession, tier_id: int) -> bool:
    result = await db.execute(
        select(func.count()).select_from(TicketSale).where(TicketSale.ticket_tier_id == tier_id)
    )
    return (result.scalar() or 0) > 0


async def create_tier(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    name: str,
    description: str | None = None,
    price_cents: int,
    max_reserved_spots: int = 0,
    display_order: int = 0,
) -> TicketTier:
    log_step(logger, "Creating tier", event_id=event_id, tier_name=name, price_cents=price_cents)
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        logger.warning("Create tier rejected: no permission", extra={"event_id": event_id})
        raise ForbiddenError("Only the event organizer or admin can manage ticket tiers")
    from app.models.event import EventStatus
    if event.status in (EventStatus.live, EventStatus.completed):
        logger.warning("Create tier rejected: event live or completed", extra={"event_id": event_id})
        raise ConflictError("Cannot add tiers while the event is live or completed")
    if price_cents < 0:
        raise ConflictError("price_cents must be >= 0")
    tier = TicketTier(
        event_id=event_id,
        name=name,
        description=description,
        price_cents=price_cents,
        max_reserved_spots=max_reserved_spots,
        display_order=display_order,
    )
    db.add(tier)
    await db.flush()
    await db.refresh(tier)
    logger.info("Tier created", extra={"event_id": event_id, "tier_id": tier.id, "tier_name": name})
    return tier


async def update_tier(
    db: AsyncSession,
    tier: TicketTier,
    user: User,
    *,
    name: str | None = None,
    description: str | None = None,
    price_cents: int | None = None,
    max_reserved_spots: int | None = None,
    display_order: int | None = None,
) -> TicketTier:
    log_step(logger, "Updating tier", event_id=tier.event_id, tier_id=tier.id)
    event = await event_service.get_or_404(db, tier.event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can manage ticket tiers")
    if price_cents is not None and price_cents != tier.price_cents:
        if await _tier_has_sales(db, tier.id):
            logger.warning("Update tier rejected: price change on tier with sales", extra={"tier_id": tier.id})
            raise ConflictError("Cannot change price after tickets have been sold for this tier")
    if name is not None:
        tier.name = name
    if description is not None:
        tier.description = description
    if price_cents is not None:
        if price_cents < 0:
            raise ConflictError("price_cents must be >= 0")
        tier.price_cents = price_cents
    if max_reserved_spots is not None:
        if max_reserved_spots < 0:
            raise ConflictError("max_reserved_spots must be >= 0")
        tier.max_reserved_spots = max_reserved_spots
    if display_order is not None:
        tier.display_order = display_order
    await db.flush()
    await db.refresh(tier)
    logger.info("Tier updated", extra={"event_id": tier.event_id, "tier_id": tier.id})
    return tier


async def delete_tier(db: AsyncSession, tier: TicketTier, user: User) -> None:
    event = await event_service.get_or_404(db, tier.event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can manage ticket tiers")
    from app.models.event import EventStatus
    if event.status in (EventStatus.selling_tickets, EventStatus.live, EventStatus.completed):
        raise ConflictError("Cannot delete ticket tiers once the event is published for ticket sales")
    await db.delete(tier)
    await db.flush()


async def set_user_discount(
    db: AsyncSession,
    *,
    event_id: int,
    target_user_id: int,
    current_user: User,
    discount_type: str,
    value: int,
) -> UserEventDiscount:
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, current_user, event):
        raise ForbiddenError("Only the event organizer or admin can set user discounts")
    if discount_type not in ("percent", "fixed_cents"):
        raise ConflictError("discount_type must be 'percent' or 'fixed_cents'")
    if discount_type == "percent" and (value < 0 or value > 100):
        raise ConflictError("percent value must be 0-100")
    if discount_type == "fixed_cents" and value < 0:
        raise ConflictError("fixed_cents must be >= 0")

    q = select(UserEventDiscount).where(
        UserEventDiscount.event_id == event_id,
        UserEventDiscount.user_id == target_user_id,
    )
    existing = (await db.execute(q)).scalar_one_or_none()
    if existing:
        existing.discount_type = discount_type
        existing.value = value
        await db.flush()
        await db.refresh(existing)
        return existing
    ued = UserEventDiscount(
        event_id=event_id,
        user_id=target_user_id,
        discount_type=discount_type,
        value=value,
    )
    db.add(ued)
    await db.flush()
    await db.refresh(ued)
    return ued


async def remove_user_discount(
    db: AsyncSession,
    *,
    event_id: int,
    target_user_id: int,
    current_user: User,
) -> None:
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, current_user, event):
        raise ForbiddenError("Only the event organizer or admin can remove user discounts")
    q = select(UserEventDiscount).where(
        UserEventDiscount.event_id == event_id,
        UserEventDiscount.user_id == target_user_id,
    )
    res = await db.execute(q)
    ued = res.scalar_one_or_none()
    if ued:
        await db.delete(ued)
        await db.flush()
