"""
Ticket purchase, refund, waitlist, scan, and list operations.
"""
import secrets
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.event import Event
from app.models.registration import Registration, RegistrationStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.user import User
from app.services import event as event_service

from app.services.ticket.pricing import compute_ticket_price
from app.services.ticket.tiers import _can_manage_event_tickets, get_tier_or_404


async def purchase_ticket(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    tier_id: int,
    quantity: int = 1,
    extra_perks: str | None = None,
) -> list[TicketSale]:
    """Customer purchases one or more tickets. Must be registered."""
    if quantity < 1 or quantity > 10:
        raise ConflictError("Quantity must be between 1 and 10")

    event = await event_service.get_or_404(db, event_id)
    tier = await get_tier_or_404(db, event_id=event_id, tier_id=tier_id)

    from sqlalchemy import text
    await db.execute(text("SELECT pg_advisory_xact_lock(:eid)"), {"eid": event_id})

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

    from app.services import platform_settings as settings_svc
    commission_cents = 0
    net_to_organizer = final_cents
    if final_cents > 0:
        commission_pct = await settings_svc.get_int(db, "ticket_commission_percent")
        if getattr(event, "community_rules", False):
            override = await settings_svc.get_str(db, "community_ticket_commission_percent")
            if override is not None and override != "":
                commission_pct = int(override)
        commission_cents = final_cents * commission_pct // 100
        net_to_organizer = final_cents - commission_cents

    from app.services import funding as funding_svc

    purchased_count_q = select(func.count()).where(
        TicketSale.event_id == event_id,
        TicketSale.status == TicketSaleStatus.purchased,
    )
    purchased_count = int((await db.execute(purchased_count_q)).scalar_one())

    total_reserved = await funding_svc.get_total_reserved_spots(db, event_id)

    use_tier_linked = getattr(event, "link_funding_to_tiers", False)

    if use_tier_linked:
        user_tier_reserved = await funding_svc.get_user_reserved_spots_for_tier(
            db, event_id, user.id, tier_id
        )
        spots_to_consume = min(quantity, user_tier_reserved)
    else:
        user_reserved = await funding_svc.get_user_reserved_spots(db, event_id, user.id)
        spots_to_consume = min(quantity, user_reserved)

    remaining_tickets = quantity - spots_to_consume

    occupied = purchased_count + total_reserved
    available = max(0, int(event.max_capacity) - occupied)

    if remaining_tickets > available:
        ticket_status = TicketSaleStatus.waitlisted
        spots_to_consume = 0
    else:
        ticket_status = TicketSaleStatus.purchased

    if use_tier_linked and spots_to_consume > 0:
        await funding_svc.consume_reserved_spots_for_tier(
            db, event_id, user.id, tier_id, spots_to_consume
        )
    else:
        for _ in range(spots_to_consume):
            await funding_svc.consume_one_reserved_spot(db, event_id, user.id)

    purchase_group_id = secrets.token_urlsafe(16) if quantity > 1 else None

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

        sale.receipt_number = f"RCP-{now.strftime('%Y%m%d')}-{event_id}-{sale.id}"
        await db.flush()
        await db.refresh(sale)
        sales.append(sale)

    try:
        from app.services import escrow as escrow_svc
        await escrow_svc.check_and_release_stage2(db, event_id=event_id)
    except Exception:
        pass

    sale_ids = [s.id for s in sales]
    loaded_q = (
        select(TicketSale)
        .where(TicketSale.id.in_(sale_ids))
        .options(
            selectinload(TicketSale.event),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.user),
        )
        .order_by(TicketSale.id.asc())
    )
    return list((await db.execute(loaded_q)).scalars().unique().all())


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
    """Return { event_id: tickets_sold_count } for each event."""
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
    """Load a single ticket sale with all relationships needed for a receipt."""
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


async def list_my_tickets(
    db: AsyncSession, *, user_id: int, offset: int = 0, limit: int = 20,
) -> Sequence[TicketSale]:
    """List ticket sales for a user (purchased + waitlisted)."""
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
        .offset(offset)
        .limit(limit)
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def list_tickets_for_user_admin(
    db: AsyncSession, *, user_id: int, limit: int = 200,
) -> Sequence[TicketSale]:
    """List all ticket sales for a user (all statuses) for admin user detail."""
    q = (
        select(TicketSale)
        .where(TicketSale.user_id == user_id)
        .options(
            selectinload(TicketSale.event),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.user),
        )
        .order_by(TicketSale.created_at.desc())
        .limit(limit)
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def list_event_ticket_sales(
    db: AsyncSession, *, event_id: int, offset: int = 0, limit: int = 20,
) -> Sequence[TicketSale]:
    """List all ticket sales for an event (organizer/admin)."""
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
        .offset(offset)
        .limit(limit)
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def list_event_scanned_ticket_sales(
    db: AsyncSession, *, event_id: int, offset: int = 0, limit: int = 20,
) -> Sequence[TicketSale]:
    """List only scanned ticket sales for an event."""
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
        .offset(offset)
        .limit(limit)
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def list_organizer_ticket_sales(
    db: AsyncSession, *, organizer_id: int, scanned_only: bool = False,
    event_status: str | None = None, genre: str | None = None,
    event_id: int | None = None, offset: int = 0, limit: int = 20,
) -> Sequence[TicketSale]:
    """List all ticket sales across all events owned by organizer_id."""
    conditions = [Event.organizer_id == organizer_id]
    if scanned_only:
        conditions.append(TicketSale.scanned_at.isnot(None))
    if event_status:
        from app.models.event import EventStatus
        try:
            conditions.append(Event.status == EventStatus(event_status))
        except ValueError:
            pass
    if genre:
        conditions.append(Event.genre == genre)
    if event_id:
        conditions.append(Event.id == event_id)
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
        .offset(offset)
        .limit(limit)
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def list_all_ticket_sales_for_admin(
    db: AsyncSession,
    *,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
    status: str | None = None,
) -> tuple[Sequence[TicketSale], int]:
    """List ticket sales for admin, optionally filtered by status. Returns (items, total)."""
    from sqlalchemy import or_ as sql_or
    base = (
        select(TicketSale)
        .join(Event, TicketSale.event_id == Event.id)
    )
    if status:
        try:
            base = base.where(TicketSale.status == TicketSaleStatus(status))
        except ValueError:
            pass
    if search:
        pattern = f"%{search}%"
        base = base.outerjoin(User, TicketSale.user_id == User.id).where(
            sql_or(Event.title.ilike(pattern), User.display_name.ilike(pattern))
        )
    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar_one()
    q = (
        base
        .options(
            selectinload(TicketSale.event),
            selectinload(TicketSale.user),
            selectinload(TicketSale.ticket_tier),
        )
        .order_by(TicketSale.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all()), int(total)


async def list_event_waitlisted_tickets(db: AsyncSession, *, event_id: int) -> Sequence[TicketSale]:
    """List waitlisted ticket sales for an event."""
    await event_service.get_or_404(db, event_id)
    q = (
        select(TicketSale)
        .where(TicketSale.event_id == event_id, TicketSale.status == TicketSaleStatus.waitlisted)
        .options(
            selectinload(TicketSale.user),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.scanned_by),
        )
        .order_by(TicketSale.created_at.asc())
    )
    res = await db.execute(q)
    return list(res.scalars().unique().all())


async def approve_waitlisted_ticket(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer approves a waitlisted ticket -> purchased."""
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
    """Organizer rejects a waitlisted ticket -> cancelled."""
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


async def request_refund(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Customer requests a refund for a purchased ticket."""
    q = select(TicketSale).where(
        TicketSale.id == ticket_sale_id,
        TicketSale.event_id == event_id,
        TicketSale.user_id == user.id,
    ).options(
        selectinload(TicketSale.user),
        selectinload(TicketSale.ticket_tier),
        selectinload(TicketSale.event),
    )
    sale = (await db.execute(q)).scalar_one_or_none()
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.purchased:
        raise ConflictError("Only purchased tickets can be refunded")
    if sale.scanned_at is not None:
        raise ConflictError("Scanned tickets cannot be refunded")

    sale.status = TicketSaleStatus.refund_requested
    await db.flush()
    await db.refresh(sale)
    return sale


async def approve_refund(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer approves a refund request."""
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can approve refunds")

    q = select(TicketSale).where(
        TicketSale.id == ticket_sale_id,
        TicketSale.event_id == event_id,
    ).options(
        selectinload(TicketSale.user),
        selectinload(TicketSale.ticket_tier),
        selectinload(TicketSale.event),
    )
    sale = (await db.execute(q)).scalar_one_or_none()
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.refund_requested:
        raise ConflictError("Only refund-requested tickets can be approved")

    sale.status = TicketSaleStatus.refund_processing
    sale.status = TicketSaleStatus.refunded
    await db.flush()
    await db.refresh(sale)
    return sale


async def reject_refund(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer rejects a refund request. Ticket goes back to purchased."""
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can reject refunds")

    q = select(TicketSale).where(
        TicketSale.id == ticket_sale_id,
        TicketSale.event_id == event_id,
    ).options(
        selectinload(TicketSale.user),
        selectinload(TicketSale.ticket_tier),
        selectinload(TicketSale.event),
    )
    sale = (await db.execute(q)).scalar_one_or_none()
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.refund_requested:
        raise ConflictError("Only refund-requested tickets can be rejected")

    sale.status = TicketSaleStatus.purchased
    await db.flush()
    await db.refresh(sale)
    return sale


async def list_refund_requests(
    db: AsyncSession, *, event_id: int
) -> list[TicketSale]:
    """List all tickets with refund_requested status for an event."""
    q = (
        select(TicketSale)
        .where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.refund_requested,
        )
        .options(
            selectinload(TicketSale.user),
            selectinload(TicketSale.ticket_tier),
            selectinload(TicketSale.event),
        )
        .order_by(TicketSale.created_at.desc())
    )
    return list((await db.execute(q)).scalars().all())


async def refund_all_tickets_for_event(db: AsyncSession, *, event_id: int) -> int:
    """Bulk refund all purchased tickets for a cancelled event. Returns count."""
    from sqlalchemy import update
    await db.execute(
        update(TicketSale)
        .where(TicketSale.event_id == event_id, TicketSale.status == TicketSaleStatus.purchased)
        .values(status=TicketSaleStatus.refund_processing)
    )
    result = await db.execute(
        update(TicketSale)
        .where(TicketSale.event_id == event_id, TicketSale.status == TicketSaleStatus.refund_processing)
        .values(status=TicketSaleStatus.refunded)
    )
    return result.rowcount or 0


async def scan_ticket(
    db: AsyncSession,
    *,
    event_id: int,
    ticket_code: str,
    scanned_by_user: User,
) -> tuple[TicketSale, bool]:
    """Organizer scans a ticket by code. Returns (ticket_sale, already_scanned)."""
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
        now = datetime.now(timezone.utc)
        sale.scanned_at = now
        sale.scanned_by_id = scanned_by_user.id
        await db.flush()
        from app.services.event import record_customer_attendance
        await record_customer_attendance(
            db,
            organizer_id=event.organizer_id,
            customer_id=sale.user_id,
            event_id=event_id,
            scanned_at=now,
        )
    q2 = select(TicketSale).where(TicketSale.id == sale.id).options(
        selectinload(TicketSale.user),
        selectinload(TicketSale.ticket_tier),
        selectinload(TicketSale.event),
        selectinload(TicketSale.scanned_by),
    )
    sale = (await db.execute(q2)).scalar_one()
    return sale, already_scanned
