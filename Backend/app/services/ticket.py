"""
Ticket tiers, sales, and discount computation.

- Only registered users (status=registered) can purchase tickets.
- Price = tier.price_cents - common_discount - selective_discount - pledge_based_discount (capped at 0).
- If discount >= price, organizer can set extra_perks on the ticket.
- Each ticket has a unique ticket_code for QR; organizer scans to mark scanned_at.
"""
import secrets
from typing import Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.event import Event, EventDiscount
from app.models.funding import Funding, FundingStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier, UserEventDiscount
from app.models.user import User, UserRole
from app.services import event as event_service


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


async def compute_ticket_price(
    db: AsyncSession,
    *,
    event_id: int,
    user_id: int,
    tier_id: int,
) -> dict:
    """
    Returns: tier_price_cents, common_discount_cents, selective_discount_cents,
    pledge_discount_cents, event_discount_cents, total_discount_cents, final_price_cents (>= 0).
    Discount cap: total discount cannot exceed ticket price.
    """
    event = await event_service.get_or_404(db, event_id)
    tier = await get_tier_or_404(db, event_id=event_id, tier_id=tier_id)
    base = tier.price_cents

    common_cents = base * event.common_discount_percent // 100

    selective_cents = 0
    sel_q = select(UserEventDiscount).where(
        UserEventDiscount.event_id == event_id,
        UserEventDiscount.user_id == user_id,
    )
    sel_res = await db.execute(sel_q)
    ued = sel_res.scalar_one_or_none()
    if ued:
        if ued.discount_type == "percent":
            selective_cents = base * min(100, ued.value) // 100
        else:
            selective_cents = min(base, ued.value)

    # Get user's total pledged amount
    sum_q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
        Funding.event_id == event_id,
        Funding.user_id == user_id,
        Funding.status == FundingStatus.pledged,
    )
    total_pledged = int((await db.execute(sum_q)).scalar_one())
    has_pledged = total_pledged > 0

    pledge_cents = 0
    if event.pledge_discount_percent > 0 and has_pledged:
        pledge_cents = total_pledged * event.pledge_discount_percent // 100
        pledge_cents = min(pledge_cents, base)

    # Apply EventDiscount rules
    event_discount_cents = 0
    disc_q = select(EventDiscount).where(EventDiscount.event_id == event_id)
    disc_rows = list((await db.execute(disc_q)).scalars().all())
    for d in disc_rows:
        if d.target == "pledgers" and not has_pledged:
            continue
        if d.target == "non_pledgers" and has_pledged:
            continue
        if d.discount_type == "ticket_percent":
            event_discount_cents += base * min(100, d.value) // 100
        elif d.discount_type == "pledge_percent":
            event_discount_cents += total_pledged * min(100, d.value) // 100
        elif d.discount_type == "fixed_cents":
            event_discount_cents += d.value

    total_discount = common_cents + selective_cents + pledge_cents + event_discount_cents
    # Cap: discount cannot exceed ticket price
    total_discount = min(total_discount, base)
    final = max(0, base - total_discount)
    return {
        "tier_price_cents": base,
        "common_discount_cents": common_cents,
        "selective_discount_cents": selective_cents,
        "pledge_discount_cents": pledge_cents,
        "event_discount_cents": event_discount_cents,
        "total_discount_cents": total_discount,
        "final_price_cents": final,
    }


async def purchase_ticket(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    tier_id: int,
    extra_perks: str | None = None,
) -> TicketSale:
    """Customer purchases a ticket. Must be registered (registered status)."""
    event = await event_service.get_or_404(db, event_id)
    tier = await get_tier_or_404(db, event_id=event_id, tier_id=tier_id)

    reg_q = select(Registration).where(
        Registration.event_id == event_id,
        Registration.user_id == user.id,
        Registration.status == RegistrationStatus.registered,
    )
    reg = (await db.execute(reg_q)).scalar_one_or_none()
    if not reg:
        raise ConflictError("Only registered attendees can purchase tickets for this event")

    price_info = await compute_ticket_price(db, event_id=event_id, user_id=user.id, tier_id=tier_id)
    final_cents = price_info["final_price_cents"]
    total_discount = price_info["total_discount_cents"]
    tier_price = price_info["tier_price_cents"]

    ticket_code = secrets.token_urlsafe(24)
    sale = TicketSale(
        event_id=event_id,
        user_id=user.id,
        ticket_tier_id=tier_id,
        ticket_code=ticket_code,
        amount_paid_cents=final_cents,
        discount_applied_cents=total_discount,
        extra_perks=extra_perks if extra_perks else (None if total_discount < tier_price else ""),
        status=TicketSaleStatus.purchased,
    )
    db.add(sale)
    await db.flush()
    await db.refresh(sale)
    # Load relationships for response (including user for attendee_display_name)
    q = select(TicketSale).where(TicketSale.id == sale.id).options(
        selectinload(TicketSale.event),
        selectinload(TicketSale.ticket_tier),
        selectinload(TicketSale.user),
    )
    loaded = (await db.execute(q)).scalar_one()
    return loaded


async def list_my_tickets(db: AsyncSession, *, user_id: int) -> Sequence[TicketSale]:
    """List ticket sales for a user (with event, tier, user loaded)."""
    q = (
        select(TicketSale)
        .where(TicketSale.user_id == user_id, TicketSale.status == TicketSaleStatus.purchased)
        .options(
            selectinload(TicketSale.event),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.user),
        )
        .order_by(TicketSale.created_at.desc())
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def list_event_ticket_sales(db: AsyncSession, *, event_id: int) -> Sequence[TicketSale]:
    """List all ticket sales for an event (organizer/admin). Includes scanned_at/scanned_by for scan list view."""
    await event_service.get_or_404(db, event_id)
    q = (
        select(TicketSale)
        .where(TicketSale.event_id == event_id)
        .options(
            selectinload(TicketSale.user),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.scanned_by),
        )
        .order_by(TicketSale.scanned_at.desc().nulls_last(), TicketSale.created_at.desc())
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def list_event_scanned_ticket_sales(db: AsyncSession, *, event_id: int) -> Sequence[TicketSale]:
    """List only scanned ticket sales for an event (organizer/admin). Same shape as list_event_ticket_sales."""
    await event_service.get_or_404(db, event_id)
    q = (
        select(TicketSale)
        .where(TicketSale.event_id == event_id, TicketSale.scanned_at.isnot(None))
        .options(
            selectinload(TicketSale.user),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.scanned_by),
        )
        .order_by(TicketSale.scanned_at.desc(), TicketSale.created_at.desc())
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def scan_ticket(
    db: AsyncSession,
    *,
    event_id: int,
    ticket_code: str,
    scanned_by_user: User,
) -> tuple[TicketSale, bool]:
    """
    Organizer scans a ticket by code. Returns (ticket_sale, already_scanned).
    If not yet scanned, sets scanned_at and scanned_by_id.
    """
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, scanned_by_user, event):
        raise ForbiddenError("Only the event organizer or admin can scan tickets")
    q = (
        select(TicketSale)
        .where(
            TicketSale.event_id == event_id,
            TicketSale.ticket_code == ticket_code.strip(),
            TicketSale.status == TicketSaleStatus.purchased,
        )
        .options(
            selectinload(TicketSale.user),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.event),
        )
    )
    res = await db.execute(q)
    sale = res.scalar_one_or_none()
    if not sale:
        raise NotFoundError("Ticket", "code not found or invalid for this event")
    already_scanned = sale.scanned_at is not None
    if not already_scanned:
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        sale.scanned_at = now
        sale.scanned_by_id = scanned_by_user.id
        await db.flush()
        # Auto-record customer attendance for the organizer
        from app.services.event import record_customer_attendance
        await record_customer_attendance(
            db,
            organizer_id=event.organizer_id,
            customer_id=sale.user_id,
            event_id=event_id,
            scanned_at=now,
        )
    # Reload with all relationships so response has attendee_display_name, scanned_at, scanned_by_display_name
    q2 = select(TicketSale).where(TicketSale.id == sale.id).options(
        selectinload(TicketSale.user),
        selectinload(TicketSale.ticket_tier),
        selectinload(TicketSale.event),
        selectinload(TicketSale.scanned_by),
    )
    sale = (await db.execute(q2)).scalar_one()
    return sale, already_scanned


async def create_tier(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    name: str,
    description: str | None = None,
    price_cents: int,
    display_order: int = 0,
) -> TicketTier:
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can manage ticket tiers")
    if price_cents < 0:
        raise ConflictError("price_cents must be >= 0")
    tier = TicketTier(
        event_id=event_id,
        name=name,
        description=description,
        price_cents=price_cents,
        display_order=display_order,
    )
    db.add(tier)
    await db.flush()
    await db.refresh(tier)
    return tier


async def update_tier(
    db: AsyncSession,
    tier: TicketTier,
    user: User,
    *,
    name: str | None = None,
    description: str | None = None,
    price_cents: int | None = None,
    display_order: int | None = None,
) -> TicketTier:
    event = await event_service.get_or_404(db, tier.event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can manage ticket tiers")
    if name is not None:
        tier.name = name
    if description is not None:
        tier.description = description
    if price_cents is not None:
        if price_cents < 0:
            raise ConflictError("price_cents must be >= 0")
        tier.price_cents = price_cents
    if display_order is not None:
        tier.display_order = display_order
    await db.flush()
    await db.refresh(tier)
    return tier


async def delete_tier(db: AsyncSession, tier: TicketTier, user: User) -> None:
    event = await event_service.get_or_404(db, tier.event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can manage ticket tiers")
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
