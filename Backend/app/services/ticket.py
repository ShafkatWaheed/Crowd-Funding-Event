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
from app.models.discount_strategy import DiscountStrategy, EventDiscountStrategyLink
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

    # Free tier: skip all discount computation
    if base == 0:
        return {
            "tier_price_cents": 0,
            "common_discount_cents": 0,
            "selective_discount_cents": 0,
            "pledge_discount_cents": 0,
            "event_discount_cents": 0,
            "total_discount_cents": 0,
            "final_price_cents": 0,
        }

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
        raw_pledge_discount = total_pledged * event.pledge_discount_percent // 100
        # If user has reserved spots, divide discount across those spots
        from app.services import funding as funding_svc
        user_reserved = await funding_svc.get_user_reserved_spots(db, event_id, user_id)
        if user_reserved > 0:
            pledge_cents = raw_pledge_discount // user_reserved
        else:
            pledge_cents = raw_pledge_discount
        pledge_cents = min(pledge_cents, base)

    # Apply EventDiscount rules + linked DiscountStrategy rules
    event_discount_cents = 0

    # 1) Inline EventDiscount rules
    disc_q = select(EventDiscount).where(EventDiscount.event_id == event_id)
    disc_rows = list((await db.execute(disc_q)).scalars().all())

    # 2) Linked DiscountStrategy rules — respect auto_apply & customer claims
    from app.models.discount_strategy import CustomerDiscountClaim
    from sqlalchemy.orm import selectinload as _sload

    link_q = (
        select(EventDiscountStrategyLink)
        .options(_sload(EventDiscountStrategyLink.strategy))
        .where(EventDiscountStrategyLink.event_id == event_id)
    )
    links = list((await db.execute(link_q)).scalars().all())

    # Get IDs of links the user has claimed
    claim_q = select(CustomerDiscountClaim.link_id).where(
        CustomerDiscountClaim.user_id == user_id,
        CustomerDiscountClaim.link_id.in_([l.id for l in links]) if links else False,
    )
    claimed_link_ids = set((await db.execute(claim_q)).scalars().all()) if links else set()

    # Combine both into one list of (discount_type, value, target)
    all_rules = [(d.discount_type, d.value, d.target) for d in disc_rows]
    for link in links:
        # auto_apply → always applied; non-auto → only if customer claimed
        if link.auto_apply or link.id in claimed_link_ids:
            s = link.strategy
            all_rules.append((s.discount_type, s.value, s.target))

    for d_type, d_value, d_target in all_rules:
        if d_target == "pledgers" and not has_pledged:
            continue
        if d_target == "non_pledgers" and has_pledged:
            continue
        if d_type == "ticket_percent":
            event_discount_cents += base * min(100, d_value) // 100
        elif d_type == "pledge_percent":
            event_discount_cents += total_pledged * min(100, d_value) // 100

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
    quantity: int = 1,
    extra_perks: str | None = None,
) -> list[TicketSale]:
    """
    Customer purchases one or more tickets in a single transaction.
    Must be registered (registered status).
    All-or-nothing: if capacity is insufficient for the full quantity,
    all tickets are placed on the waitlist.
    Returns a list of created TicketSale records.
    """
    if quantity < 1 or quantity > 10:
        raise ConflictError("Quantity must be between 1 and 10")

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

    # Compute platform commission (skip for free tickets)
    from app.services import platform_settings as settings_svc
    commission_cents = 0
    net_to_organizer = final_cents
    if final_cents > 0:
        commission_pct = await settings_svc.get_int(db, "ticket_commission_percent")
        commission_cents = final_cents * commission_pct // 100
        net_to_organizer = final_cents - commission_cents

    # ── Capacity check with reserved spots ──
    from app.services import funding as funding_svc

    purchased_count_q = select(func.count()).where(
        TicketSale.event_id == event_id,
        TicketSale.status == TicketSaleStatus.purchased,
    )
    purchased_count = int((await db.execute(purchased_count_q)).scalar_one())

    user_reserved = await funding_svc.get_user_reserved_spots(db, event_id, user.id)
    total_reserved = await funding_svc.get_total_reserved_spots(db, event_id)

    # Determine how many reserved spots to consume (min of quantity and user's reserved)
    spots_to_consume = min(quantity, user_reserved)
    remaining_tickets = quantity - spots_to_consume

    # Check capacity for the remaining (non-reserved) tickets
    occupied = purchased_count + total_reserved  # total_reserved includes user_reserved
    available = max(0, int(event.max_capacity) - occupied)

    if remaining_tickets > available:
        # Not enough general capacity — all tickets go to waitlist
        ticket_status = TicketSaleStatus.waitlisted
        spots_to_consume = 0  # Don't consume reserved spots if waitlisted
    else:
        ticket_status = TicketSaleStatus.purchased

    # Consume reserved spots
    for _ in range(spots_to_consume):
        await funding_svc.consume_one_reserved_spot(db, event_id, user.id)

    # Generate purchase group ID for multi-ticket purchases
    purchase_group_id = secrets.token_urlsafe(16) if quantity > 1 else None

    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)

    sales: list[TicketSale] = []
    for _ in range(quantity):
        ticket_code = secrets.token_urlsafe(24)
        sale = TicketSale(
            event_id=event_id,
            user_id=user.id,
            ticket_tier_id=tier_id,
            purchase_group_id=purchase_group_id,
            ticket_code=ticket_code,
            amount_paid_cents=final_cents,
            discount_applied_cents=total_discount,
            commission_cents=commission_cents,
            net_to_organizer_cents=net_to_organizer,
            extra_perks=extra_perks if extra_perks else (None if total_discount < tier_price else ""),
            status=ticket_status,
        )
        db.add(sale)
        await db.flush()
        await db.refresh(sale)

        # Generate human-readable receipt number: RCP-YYYYMMDD-eventId-saleId
        sale.receipt_number = f"RCP-{now.strftime('%Y%m%d')}-{event_id}-{sale.id}"
        await db.flush()
        await db.refresh(sale)
        sales.append(sale)

    # Load relationships for response
    loaded_sales: list[TicketSale] = []
    for sale in sales:
        q = select(TicketSale).where(TicketSale.id == sale.id).options(
            selectinload(TicketSale.event),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.user),
        )
        loaded = (await db.execute(q)).scalar_one()
        loaded_sales.append(loaded)
    return loaded_sales


async def get_purchase_group_tickets(
    db: AsyncSession, *, purchase_group_id: str, user_id: int | None = None
) -> list[TicketSale]:
    """Load all ticket sales in a purchase group with relationships."""
    q = (
        select(TicketSale)
        .where(TicketSale.purchase_group_id == purchase_group_id)
        .options(
            selectinload(TicketSale.event),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.user),
        )
        .order_by(TicketSale.id.asc())
    )
    sales = list((await db.execute(q)).scalars().unique().all())
    if not sales:
        raise NotFoundError("PurchaseGroup", purchase_group_id)
    if user_id is not None and sales[0].user_id != user_id:
        raise ForbiddenError("You can only view your own purchase groups")
    return sales


async def get_ticket_sold_counts_for_events(
    db: AsyncSession,
    *,
    event_ids: list[int],
) -> dict[int, int]:
    """Return { event_id: tickets_sold_count } for each event. Used for list/cards."""
    if not event_ids:
        return {}
    q = (
        select(TicketSale.event_id, func.count().label("cnt"))
        .where(
            TicketSale.event_id.in_(event_ids),
            TicketSale.status == TicketSaleStatus.purchased,
        )
        .group_by(TicketSale.event_id)
    )
    result = await db.execute(q)
    return {int(row.event_id): int(row.cnt) for row in result.all()}


async def get_ticket_sales_stats(db: AsyncSession, *, event_id: int) -> dict:
    """Return total_sold and total_scanned counts for an event."""
    sold_q = select(func.count()).where(
        TicketSale.event_id == event_id,
        TicketSale.status == TicketSaleStatus.purchased,
    )
    total_sold = int((await db.execute(sold_q)).scalar_one())

    scanned_q = select(func.count()).where(
        TicketSale.event_id == event_id,
        TicketSale.status == TicketSaleStatus.purchased,
        TicketSale.scanned_at.isnot(None),
    )
    total_scanned = int((await db.execute(scanned_q)).scalar_one())
    return {"total_sold": total_sold, "total_scanned": total_scanned}


async def get_ticket_receipt(
    db: AsyncSession, *, sale_id: int, user_id: int | None = None
) -> TicketSale:
    """
    Load a single ticket sale with all relationships needed for a receipt.
    If user_id is provided, verifies the sale belongs to that user.
    """
    q = (
        select(TicketSale)
        .where(TicketSale.id == sale_id)
        .options(
            selectinload(TicketSale.event),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.user),
        )
    )
    sale = (await db.execute(q)).scalar_one_or_none()
    if not sale:
        raise NotFoundError("TicketSale", sale_id)
    if user_id is not None and sale.user_id != user_id:
        from app.core.exceptions import ForbiddenError as FE
        raise FE("You can only view your own ticket receipts")
    return sale


async def list_my_tickets(db: AsyncSession, *, user_id: int) -> Sequence[TicketSale]:
    """List ticket sales for a user (purchased + waitlisted, with event, tier, user loaded)."""
    q = (
        select(TicketSale)
        .where(
            TicketSale.user_id == user_id,
            TicketSale.status.in_([TicketSaleStatus.purchased, TicketSaleStatus.waitlisted]),
        )
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


async def list_organizer_ticket_sales(
    db: AsyncSession, *, organizer_id: int, scanned_only: bool = False,
) -> Sequence[TicketSale]:
    """List all ticket sales across all events owned by organizer_id. Single query, no N+1."""
    conditions = [Event.organizer_id == organizer_id]
    if scanned_only:
        conditions.append(TicketSale.scanned_at.isnot(None))
    q = (
        select(TicketSale)
        .join(Event, TicketSale.event_id == Event.id)
        .where(*conditions)
        .options(
            selectinload(TicketSale.event),
            selectinload(TicketSale.user),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.scanned_by),
        )
        .order_by(TicketSale.created_at.desc())
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def list_event_waitlisted_tickets(db: AsyncSession, *, event_id: int) -> Sequence[TicketSale]:
    """List waitlisted ticket sales for an event (organizer/admin)."""
    await event_service.get_or_404(db, event_id)
    q = (
        select(TicketSale)
        .where(TicketSale.event_id == event_id, TicketSale.status == TicketSaleStatus.waitlisted)
        .options(
            selectinload(TicketSale.user),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.scanned_by),
        )
        .order_by(TicketSale.created_at.asc())  # FIFO: first-come first-served
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def approve_waitlisted_ticket(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer approves a waitlisted ticket → purchased."""
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can approve waitlisted tickets")

    q = select(TicketSale).where(
        TicketSale.id == ticket_sale_id, TicketSale.event_id == event_id,
    ).options(
        selectinload(TicketSale.user),
        selectinload(TicketSale.ticket_tier),
        selectinload(TicketSale.event),
    )
    sale = (await db.execute(q)).scalar_one_or_none()
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.waitlisted:
        raise ConflictError("Only waitlisted tickets can be approved")

    sale.status = TicketSaleStatus.purchased
    await db.flush()
    await db.refresh(sale)
    return sale


async def reject_waitlisted_ticket(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer rejects a waitlisted ticket → cancelled."""
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can reject waitlisted tickets")

    q = select(TicketSale).where(
        TicketSale.id == ticket_sale_id, TicketSale.event_id == event_id,
    ).options(
        selectinload(TicketSale.user),
        selectinload(TicketSale.ticket_tier),
        selectinload(TicketSale.event),
    )
    sale = (await db.execute(q)).scalar_one_or_none()
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.waitlisted:
        raise ConflictError("Only waitlisted tickets can be rejected")

    sale.status = TicketSaleStatus.cancelled
    await db.flush()
    await db.refresh(sale)
    return sale


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
    from app.models.event import EventStatus
    if event.status in (EventStatus.selling_tickets, EventStatus.live, EventStatus.completed):
        raise ConflictError("Cannot delete ticket tiers while tickets are on sale or the event is live/completed")
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
