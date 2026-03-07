"""
Ticket purchase, refund, waitlist, scan, and list operations.
"""
import secrets
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.user import User
from app.repositories.ticket_repo import ticket_repo
from app.services import event as event_service

from app.services.ticket.pricing import compute_ticket_price
from app.services.ticket.tiers import _can_manage_event_tickets, get_tier_or_404

logger = get_logger("svc.ticket.sales")


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
    log_step(logger, "Purchasing tickets", event_id=event_id, user_id=user.id, tier_id=tier_id, quantity=quantity)
    if quantity < 1:
        logger.warning("Ticket purchase rejected: invalid quantity", extra={"event_id": event_id, "user_id": user.id, "quantity": quantity})
        raise ConflictError("Quantity must be at least 1")

    from app.services import platform_settings as settings_svc
    if await settings_svc.get_bool(db, "max_tickets_backend_enabled"):
        max_qty = await settings_svc.get_int(db, "max_tickets_per_purchase")
        if quantity > max_qty:
            raise ConflictError(f"Quantity must not exceed {max_qty}")

    event = await event_service.get_or_404(db, event_id)

    from app.services.age_verification import enforce_age_limit
    enforce_age_limit(user.birthday, event.age_restricted, event.min_age, "purchase tickets for this event")

    tier = await get_tier_or_404(db, event_id=event_id, tier_id=tier_id)

    await ticket_repo.advisory_lock(db, event_id)

    reg = await ticket_repo.get_active_registration(db, event_id, user.id)
    if not reg:
        logger.warning("Ticket purchase rejected: not registered", extra={"event_id": event_id, "user_id": user.id})
        raise ConflictError("Only registered attendees can purchase tickets for this event")

    price_info = await compute_ticket_price(db, event_id=event_id, user_id=user.id, tier_id=tier_id)
    final_cents = price_info["final_price_cents"]
    total_discount = price_info["total_discount_cents"]
    tier_price = price_info["tier_price_cents"]

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

    purchased_count = await ticket_repo.count_purchased(db, event_id)

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

    gateway_txn_id: str | None = None
    gateway_auth: str | None = None
    total_charge = final_cents * quantity
    if total_charge > 0 and ticket_status == TicketSaleStatus.purchased:
        try:
            from app.services.payment_gateway import get_gateway
            gw = await get_gateway(db)
            result = await gw.charge(
                db,
                user_id=user.id,
                amount_cents=total_charge,
                description=f"Ticket purchase: {quantity}x {tier.name} for event {event_id}",
                idempotency_key=purchase_group_id or f"ticket-{event_id}-{user.id}-{tier_id}",
                commission_cents=commission_cents * quantity,
            )
            if result.status == "failed":
                reason = getattr(result, "failure_reason", "card declined")
                logger.warning("Ticket purchase payment failed", extra={"event_id": event_id, "user_id": user.id, "tier_id": tier_id, "reason": reason})
                raise ConflictError(f"Payment failed: {reason}")
            gateway_txn_id = result.transaction_id
            gateway_auth = result.authorization_code
        except ConflictError:
            raise
        except Exception as exc:
            logger.warning("Ticket purchase payment error", extra={"event_id": event_id, "user_id": user.id, "error": str(exc)})
            raise ConflictError(f"Payment processing error: {exc}")

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
            gateway_transaction_id=gateway_txn_id,
            gateway_auth_code=gateway_auth,
        )
        sale = await ticket_repo.create_sale(db, sale)

        await ticket_repo.set_receipt_number(db, sale, f"RCP-{now.strftime('%Y%m%d')}-{event_id}-{sale.id}")
        sales.append(sale)

    try:
        from app.services import ticket_escrow as te_svc
        await te_svc.get_or_create(db, event_id=event_id)
        await te_svc.refresh_total(db, event_id)
    except Exception:
        pass

    try:
        from app.services import escrow as escrow_svc
        await escrow_svc.check_and_release_stage2(db, event_id=event_id)
    except Exception:
        pass

    sale_ids = [s.id for s in sales]
    sales_result = await ticket_repo.load_sales_by_ids(db, sale_ids)
    purchased_count = sum(1 for s in sales_result if s.status == TicketSaleStatus.purchased)
    waitlisted_count = sum(1 for s in sales_result if s.status == TicketSaleStatus.waitlisted)
    logger.info("Ticket purchase completed", extra={"event_id": event_id, "user_id": user.id, "quantity": quantity, "purchased": purchased_count, "waitlisted": waitlisted_count})
    return sales_result


async def get_purchase_group_tickets(
    db: AsyncSession, *, purchase_group_id: str, user_id: int | None = None
) -> list[TicketSale]:
    """Load all ticket sales in a purchase group with relationships."""
    sales = await ticket_repo.get_purchase_group_sales(db, purchase_group_id)
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
    return await ticket_repo.get_sold_counts_for_events(db, event_ids)


async def get_total_tier_capacity_for_events(
    db: AsyncSession,
    *,
    event_ids: list[int],
) -> dict[int, int]:
    """Return { event_id: sum_of_tier_max_reserved_spots } for each event."""
    return await ticket_repo.get_total_tier_capacity_for_events(db, event_ids)


async def get_total_tier_capacity(
    db: AsyncSession,
    *,
    event_id: int,
) -> int:
    """Return total tier capacity for a single event."""
    return await ticket_repo.get_total_tier_capacity(db, event_id)


async def get_ticket_sales_stats(db: AsyncSession, *, event_id: int) -> dict:
    """Return total_sold and total_scanned counts for an event."""
    total_sold = await ticket_repo.count_purchased(db, event_id)
    total_scanned = await ticket_repo.count_scanned(db, event_id)
    return {"total_sold": total_sold, "total_scanned": total_scanned}


async def get_ticket_receipt(
    db: AsyncSession, *, sale_id: int, user_id: int | None = None
) -> TicketSale:
    """Load a single ticket sale with all relationships needed for a receipt."""
    sale = await ticket_repo.get_sale_with_relations(db, sale_id)
    if not sale:
        raise NotFoundError("TicketSale", sale_id)
    if user_id is not None and sale.user_id != user_id:
        raise ForbiddenError("You can only view your own ticket receipts")
    return sale


async def list_my_tickets(
    db: AsyncSession, *, user_id: int, offset: int = 0, limit: int = 20,
    sort_by: str = "newest",
) -> Sequence[TicketSale]:
    """List ticket sales for a user (all statuses visible to customer)."""
    return await ticket_repo.list_my_tickets(
        db, user_id=user_id, offset=offset, limit=limit, sort_by=sort_by,
    )


async def list_tickets_for_user_admin(
    db: AsyncSession, *, user_id: int, limit: int = 200,
) -> Sequence[TicketSale]:
    """List all ticket sales for a user (all statuses) for admin user detail."""
    return await ticket_repo.list_for_user_admin(db, user_id=user_id, limit=limit)


async def list_event_ticket_sales(
    db: AsyncSession, *, event_id: int, offset: int = 0, limit: int = 20,
) -> Sequence[TicketSale]:
    """List all ticket sales for an event (organizer/admin)."""
    await event_service.get_or_404(db, event_id)
    return await ticket_repo.list_event_sales(db, event_id=event_id, offset=offset, limit=limit)


async def list_event_scanned_ticket_sales(
    db: AsyncSession, *, event_id: int, offset: int = 0, limit: int = 20,
) -> Sequence[TicketSale]:
    """List only scanned ticket sales for an event."""
    await event_service.get_or_404(db, event_id)
    return await ticket_repo.list_event_scanned_sales(db, event_id=event_id, offset=offset, limit=limit)


async def list_organizer_ticket_sales(
    db: AsyncSession, *, organizer_id: int, scanned_only: bool = False,
    event_status: str | None = None, genre: str | None = None,
    event_id: int | None = None, offset: int = 0, limit: int = 20,
) -> Sequence[TicketSale]:
    """List all ticket sales across all events owned by organizer_id."""
    return await ticket_repo.list_organizer_sales(
        db, organizer_id=organizer_id, scanned_only=scanned_only,
        event_status=event_status, genre=genre, event_id=event_id,
        offset=offset, limit=limit,
    )


async def list_organizer_refund_requests(
    db: AsyncSession, *, organizer_id: int,
    event_id: int | None = None,
    offset: int = 0, limit: int = 20,
) -> Sequence[TicketSale]:
    """List all pending refund requests across all events owned by organizer_id."""
    return await ticket_repo.list_organizer_refund_requests(
        db, organizer_id=organizer_id, event_id=event_id, offset=offset, limit=limit,
    )


async def list_all_ticket_sales_for_admin(
    db: AsyncSession,
    *,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
    status: str | None = None,
) -> tuple[Sequence[TicketSale], int]:
    """List ticket sales for admin, optionally filtered by status. Returns (items, total)."""
    return await ticket_repo.list_all_for_admin(
        db, offset=offset, limit=limit, search=search, status=status,
    )


async def list_event_waitlisted_tickets(db: AsyncSession, *, event_id: int) -> Sequence[TicketSale]:
    """List waitlisted ticket sales for an event."""
    await event_service.get_or_404(db, event_id)
    return await ticket_repo.list_event_waitlisted(db, event_id=event_id)


async def approve_waitlisted_ticket(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer approves a waitlisted ticket -> purchased."""
    log_step(logger, "Approving waitlisted ticket", event_id=event_id, ticket_sale_id=ticket_sale_id)
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can approve waitlisted tickets")

    sale = await ticket_repo.get_sale_for_event(db, ticket_sale_id, event_id)
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.waitlisted:
        logger.warning("Approve waitlist rejected: not waitlisted", extra={"event_id": event_id, "ticket_sale_id": ticket_sale_id})
        raise ConflictError("Only waitlisted tickets can be approved")

    await ticket_repo.update_sale_status(db, sale, TicketSaleStatus.purchased)
    logger.info("Waitlisted ticket approved", extra={"event_id": event_id, "ticket_sale_id": ticket_sale_id})
    return sale


async def reject_waitlisted_ticket(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer rejects a waitlisted ticket -> cancelled."""
    log_step(logger, "Rejecting waitlisted ticket", event_id=event_id, ticket_sale_id=ticket_sale_id)
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can reject waitlisted tickets")

    sale = await ticket_repo.get_sale_for_event(db, ticket_sale_id, event_id)
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.waitlisted:
        logger.warning("Reject waitlist failed: not waitlisted", extra={"event_id": event_id, "ticket_sale_id": ticket_sale_id})
        raise ConflictError("Only waitlisted tickets can be rejected")

    await ticket_repo.update_sale_status(db, sale, TicketSaleStatus.cancelled)
    return sale


async def request_refund(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Customer requests a refund for a purchased ticket."""
    log_step(logger, "Requesting ticket refund", event_id=event_id, ticket_sale_id=ticket_sale_id, user_id=user.id)
    sale = await ticket_repo.get_sale_for_user(db, ticket_sale_id, event_id, user.id)
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status in (
        TicketSaleStatus.refund_requested,
        TicketSaleStatus.refund_processing,
        TicketSaleStatus.refunded,
    ):
        return sale
    if sale.status != TicketSaleStatus.purchased:
        logger.warning("Refund request rejected: not purchased", extra={"event_id": event_id, "ticket_sale_id": ticket_sale_id, "status": sale.status})
        raise ConflictError("Only purchased tickets can be refunded")
    if sale.scanned_at is not None:
        logger.warning("Refund request rejected: already scanned", extra={"event_id": event_id, "ticket_sale_id": ticket_sale_id})
        raise ConflictError("Scanned tickets cannot be refunded")

    await ticket_repo.update_sale_status(db, sale, TicketSaleStatus.refund_requested)
    return sale


async def approve_refund(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer approves a refund request."""
    log_step(logger, "Approving ticket refund", event_id=event_id, ticket_sale_id=ticket_sale_id)
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can approve refunds")

    sale = await ticket_repo.get_sale_for_event(db, ticket_sale_id, event_id)
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status in (TicketSaleStatus.refund_processing, TicketSaleStatus.refunded):
        return sale
    if sale.status != TicketSaleStatus.refund_requested:
        logger.warning("Approve refund rejected: wrong status", extra={"event_id": event_id, "ticket_sale_id": ticket_sale_id, "status": sale.status})
        raise ConflictError("Only refund-requested tickets can be approved")

    await ticket_repo.update_sale_status(db, sale, TicketSaleStatus.refund_processing)

    from app.worker.redis_pool import enqueue
    await enqueue("process_ticket_refund", sale.id)

    return sale


async def reject_refund(
    db: AsyncSession, *, event_id: int, ticket_sale_id: int, user: User
) -> TicketSale:
    """Organizer rejects a refund request. Ticket goes back to purchased."""
    event = await event_service.get_or_404(db, event_id)
    if not await _can_manage_event_tickets(db, user, event):
        raise ForbiddenError("Only the event organizer or admin can reject refunds")

    sale = await ticket_repo.get_sale_for_event(db, ticket_sale_id, event_id)
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.refund_requested:
        raise ConflictError("Only refund-requested tickets can be rejected")

    await ticket_repo.update_sale_status(db, sale, TicketSaleStatus.purchased)
    return sale


async def list_refund_requests(
    db: AsyncSession, *, event_id: int
) -> list[TicketSale]:
    """List all tickets with refund_requested status for an event."""
    return await ticket_repo.list_refund_requests(db, event_id=event_id)


async def refund_all_tickets_for_event(db: AsyncSession, *, event_id: int) -> int:
    """Bulk refund all purchased tickets for a cancelled event.

    Marks tickets as refund_processing, then enqueues ARQ tasks for actual refund.
    """
    log_step(logger, "Refunding all tickets for event", event_id=event_id)
    ids = await ticket_repo.bulk_mark_refund_processing(db, event_id)

    from app.worker.redis_pool import enqueue
    for tid in ids:
        await enqueue("process_ticket_refund", tid)

    logger.info("Refund all tickets enqueued", extra={"event_id": event_id, "count": len(ids)})
    return len(ids)


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
    sale = await ticket_repo.get_sale_by_code(db, event_id, ticket_code)
    if not sale:
        raise NotFoundError("Ticket", "code not found or invalid for this event")
    already_scanned = sale.scanned_at is not None
    if not already_scanned:
        now = datetime.now(timezone.utc)
        await ticket_repo.mark_scanned(db, sale, now, scanned_by_user.id)
        from app.services.event import record_customer_attendance
        await record_customer_attendance(
            db,
            organizer_id=event.organizer_id,
            customer_id=sale.user_id,
            event_id=event_id,
            scanned_at=now,
        )
    sale = await ticket_repo.reload_with_scanned_by(db, sale.id)
    return sale, already_scanned
