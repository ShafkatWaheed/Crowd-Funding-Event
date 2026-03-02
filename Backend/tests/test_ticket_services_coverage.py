"""
Service-level tests for ticket/pricing.py, ticket/sales.py, ticket/tiers.py.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock, MagicMock
from dataclasses import dataclass

from app.models.event import Event, EventStatus
from app.models.ticket import TicketTier, TicketSale, TicketSaleStatus, UserEventDiscount
from app.models.funding import Funding, FundingStatus
from app.models.user import User, UserRole
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError

from app.services.ticket import tiers as tier_svc
from app.services.ticket import sales as sales_svc


# ===========================================================================
# TIERS: list, create, update, delete
# ===========================================================================

@pytest.mark.asyncio
async def test_list_tiers(db_session, test_event_approved, test_ticket_tier):
    """List tiers for event."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await tier_svc.list_tiers(db_session, event_id=test_event_approved.id)
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_tiers_event_not_found(db_session, test_users):
    """List tiers for non-existent event fails."""
    with pytest.raises(NotFoundError):
        await tier_svc.list_tiers(db_session, event_id=99999)


@pytest.mark.asyncio
async def test_get_tier_or_404(db_session, test_event_approved, test_ticket_tier):
    """Get tier by ID."""
    result = await tier_svc.get_tier_or_404(
        db_session, event_id=test_event_approved.id, tier_id=test_ticket_tier.id
    )
    assert result.id == test_ticket_tier.id


@pytest.mark.asyncio
async def test_get_tier_or_404_not_found(db_session, test_event_approved):
    """Get non-existent tier fails."""
    with pytest.raises(NotFoundError, match="TicketTier"):
        await tier_svc.get_tier_or_404(
            db_session, event_id=test_event_approved.id, tier_id=99999
        )


@pytest.mark.asyncio
async def test_create_tier(db_session, test_event_approved, test_users):
    """Create a ticket tier."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        tier = await tier_svc.create_tier(
            db_session,
            event_id=test_event_approved.id,
            user=organizer,
            name="VIP",
            price_cents=5000,
        )
    assert tier.name == "VIP"
    assert tier.price_cents == 5000


@pytest.mark.asyncio
async def test_create_tier_forbidden(db_session, test_event_approved, test_users):
    """Customer cannot create tier."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ForbiddenError):
            await tier_svc.create_tier(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                name="VIP",
                price_cents=5000,
            )


@pytest.mark.asyncio
async def test_create_tier_negative_price(db_session, test_event_approved, test_users):
    """Negative price fails."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="price_cents"):
            await tier_svc.create_tier(
                db_session,
                event_id=test_event_approved.id,
                user=organizer,
                name="Bad",
                price_cents=-100,
            )


@pytest.mark.asyncio
async def test_create_tier_live_event(db_session, test_event_approved, test_users):
    """Cannot add tier to live event."""
    organizer = test_users["organizer"]
    test_event_approved.status = EventStatus.live
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="live"):
            await tier_svc.create_tier(
                db_session,
                event_id=test_event_approved.id,
                user=organizer,
                name="Late",
                price_cents=1000,
            )


@pytest.mark.asyncio
async def test_update_tier_name(db_session, test_event_approved, test_ticket_tier, test_users):
    """Update tier name."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await tier_svc.update_tier(
            db_session, test_ticket_tier, organizer,
            name="Premium",
        )
    assert result.name == "Premium"


@pytest.mark.asyncio
async def test_update_tier_price_no_sales(db_session, test_event_approved, test_ticket_tier, test_users):
    """Update tier price when no sales exist."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await tier_svc.update_tier(
            db_session, test_ticket_tier, organizer,
            price_cents=3000,
        )
    assert result.price_cents == 3000


@pytest.mark.asyncio
async def test_update_tier_price_with_sales(db_session, test_event_approved, test_ticket_tier, test_ticket_sale, test_users):
    """Cannot change price after tickets sold."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="price"):
            await tier_svc.update_tier(
                db_session, test_ticket_tier, organizer,
                price_cents=9999,
            )


@pytest.mark.asyncio
async def test_update_tier_negative_price(db_session, test_event_approved, test_ticket_tier, test_users):
    """Negative price update fails."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="price_cents"):
            await tier_svc.update_tier(
                db_session, test_ticket_tier, organizer,
                price_cents=-1,
            )


@pytest.mark.asyncio
async def test_delete_tier(db_session, test_event_approved, test_users):
    """Delete tier from approved event."""
    organizer = test_users["organizer"]
    tier = TicketTier(
        event_id=test_event_approved.id,
        name="ToDelete",
        price_cents=1000,
        display_order=5,
    )
    db_session.add(tier)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await tier_svc.delete_tier(db_session, tier, organizer)


@pytest.mark.asyncio
async def test_delete_tier_selling_event(db_session, test_event_approved, test_ticket_tier, test_users):
    """Cannot delete tier from selling event."""
    organizer = test_users["organizer"]
    test_event_approved.status = EventStatus.selling_tickets
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="published"):
            await tier_svc.delete_tier(db_session, test_ticket_tier, organizer)


@pytest.mark.asyncio
async def test_delete_tier_forbidden(db_session, test_event_approved, test_ticket_tier, test_users):
    """Customer cannot delete tier."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ForbiddenError):
            await tier_svc.delete_tier(db_session, test_ticket_tier, customer)


# ===========================================================================
# TIERS: set_user_discount, remove_user_discount
# ===========================================================================

@pytest.mark.asyncio
async def test_set_user_discount(db_session, test_event_approved, test_users):
    """Set selective discount for a user."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        disc = await tier_svc.set_user_discount(
            db_session,
            event_id=test_event_approved.id,
            target_user_id=customer.id,
            current_user=organizer,
            discount_type="percent",
            value=20,
        )
    assert disc.value == 20


@pytest.mark.asyncio
async def test_set_user_discount_invalid_type(db_session, test_event_approved, test_users):
    """Invalid discount type."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="discount_type"):
            await tier_svc.set_user_discount(
                db_session,
                event_id=test_event_approved.id,
                target_user_id=customer.id,
                current_user=organizer,
                discount_type="invalid",
                value=10,
            )


@pytest.mark.asyncio
async def test_set_user_discount_percent_out_of_range(db_session, test_event_approved, test_users):
    """Percent value > 100."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="percent"):
            await tier_svc.set_user_discount(
                db_session,
                event_id=test_event_approved.id,
                target_user_id=customer.id,
                current_user=organizer,
                discount_type="percent",
                value=150,
            )


@pytest.mark.asyncio
async def test_remove_user_discount(db_session, test_event_approved, test_users):
    """Remove user discount."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await tier_svc.set_user_discount(
            db_session,
            event_id=test_event_approved.id,
            target_user_id=customer.id,
            current_user=organizer,
            discount_type="percent",
            value=10,
        )
        await tier_svc.remove_user_discount(
            db_session,
            event_id=test_event_approved.id,
            target_user_id=customer.id,
            current_user=organizer,
        )


# ===========================================================================
# SALES: purchase_ticket
# ===========================================================================

@pytest.mark.asyncio
async def test_purchase_ticket_zero_quantity(db_session, test_event_approved, test_ticket_tier, test_registration, test_users):
    """Quantity < 1 fails."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="Quantity"):
            await sales_svc.purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                tier_id=test_ticket_tier.id,
                quantity=0,
            )


@pytest.mark.asyncio
async def test_list_my_tickets(db_session, test_ticket_sale, test_users):
    """List customer tickets."""
    customer = test_users["customer"]
    result = await sales_svc.list_my_tickets(db_session, user_id=customer.id)
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_my_tickets_sort(db_session, test_ticket_sale, test_users):
    """List tickets with sort options."""
    customer = test_users["customer"]
    for sort_by in ("newest", "oldest", "price_high", "price_low"):
        result = await sales_svc.list_my_tickets(db_session, user_id=customer.id, sort_by=sort_by)
        assert isinstance(result, (list, tuple))


@pytest.mark.asyncio
async def test_get_ticket_receipt(db_session, test_ticket_sale, test_users):
    """Get ticket receipt."""
    customer = test_users["customer"]
    result = await sales_svc.get_ticket_receipt(db_session, sale_id=test_ticket_sale.id, user_id=customer.id)
    assert result.id == test_ticket_sale.id


@pytest.mark.asyncio
async def test_get_ticket_receipt_not_found(db_session, test_users):
    """Get non-existent ticket receipt."""
    with pytest.raises(NotFoundError, match="TicketSale"):
        await sales_svc.get_ticket_receipt(db_session, sale_id=99999)


@pytest.mark.asyncio
async def test_get_ticket_receipt_wrong_user(db_session, test_ticket_sale, test_users):
    """Get another user's ticket receipt fails."""
    organizer = test_users["organizer"]
    with pytest.raises(ForbiddenError):
        await sales_svc.get_ticket_receipt(
            db_session, sale_id=test_ticket_sale.id, user_id=organizer.id
        )


@pytest.mark.asyncio
async def test_get_ticket_sales_stats(db_session, test_event_approved, test_ticket_sale):
    """Get ticket sales stats."""
    result = await sales_svc.get_ticket_sales_stats(db_session, event_id=test_event_approved.id)
    assert "total_sold" in result
    assert result["total_sold"] >= 1


@pytest.mark.asyncio
async def test_list_event_ticket_sales(db_session, test_event_approved, test_ticket_sale):
    """List ticket sales for event."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await sales_svc.list_event_ticket_sales(db_session, event_id=test_event_approved.id)
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_event_scanned_sales(db_session, test_event_approved, test_ticket_sale):
    """List scanned ticket sales (should be empty since no scans)."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await sales_svc.list_event_scanned_ticket_sales(db_session, event_id=test_event_approved.id)
    assert len(result) == 0


@pytest.mark.asyncio
async def test_get_ticket_sold_counts(db_session, test_event_approved, test_ticket_sale):
    """Get sold counts across events."""
    result = await sales_svc.get_ticket_sold_counts_for_events(
        db_session, event_ids=[test_event_approved.id]
    )
    assert test_event_approved.id in result


@pytest.mark.asyncio
async def test_list_organizer_ticket_sales(db_session, test_event_approved, test_ticket_sale, test_users):
    """List organizer ticket sales."""
    organizer = test_users["organizer"]
    result = await sales_svc.list_organizer_ticket_sales(
        db_session, organizer_id=organizer.id
    )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_organizer_refund_requests(db_session, test_event_approved, test_users):
    """List organizer refund requests (empty)."""
    organizer = test_users["organizer"]
    result = await sales_svc.list_organizer_refund_requests(
        db_session, organizer_id=organizer.id
    )
    assert len(result) == 0


# ===========================================================================
# SALES: refund workflow
# ===========================================================================

@pytest.mark.asyncio
async def test_request_refund(db_session, test_event_approved, test_ticket_sale, test_users):
    """Customer requests refund."""
    customer = test_users["customer"]
    result = await sales_svc.request_refund(
        db_session,
        event_id=test_event_approved.id,
        ticket_sale_id=test_ticket_sale.id,
        user=customer,
    )
    assert result.status == TicketSaleStatus.refund_requested


@pytest.mark.asyncio
async def test_request_refund_not_found(db_session, test_event_approved, test_users):
    """Request refund for non-existent ticket."""
    customer = test_users["customer"]
    with pytest.raises(NotFoundError, match="TicketSale"):
        await sales_svc.request_refund(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=99999,
            user=customer,
        )


@pytest.mark.asyncio
async def test_request_refund_already_refunded(db_session, test_event_approved, test_ticket_sale, test_users):
    """Request refund on already refunded ticket returns as-is."""
    customer = test_users["customer"]
    test_ticket_sale.status = TicketSaleStatus.refunded
    await db_session.flush()
    result = await sales_svc.request_refund(
        db_session,
        event_id=test_event_approved.id,
        ticket_sale_id=test_ticket_sale.id,
        user=customer,
    )
    assert result.status == TicketSaleStatus.refunded


@pytest.mark.asyncio
async def test_approve_refund(db_session, test_event_approved, test_ticket_sale, test_users):
    """Organizer approves refund."""
    organizer = test_users["organizer"]
    test_ticket_sale.status = TicketSaleStatus.refund_requested
    await db_session.flush()
    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        result = await sales_svc.approve_refund(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=test_ticket_sale.id,
            user=organizer,
        )
    assert result.status == TicketSaleStatus.refund_processing


@pytest.mark.asyncio
async def test_approve_refund_forbidden(db_session, test_event_approved, test_ticket_sale, test_users):
    """Customer cannot approve refund."""
    customer = test_users["customer"]
    test_ticket_sale.status = TicketSaleStatus.refund_requested
    await db_session.flush()
    with pytest.raises(ForbiddenError):
        await sales_svc.approve_refund(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=test_ticket_sale.id,
            user=customer,
        )


@pytest.mark.asyncio
async def test_reject_refund(db_session, test_event_approved, test_ticket_sale, test_users):
    """Organizer rejects refund."""
    organizer = test_users["organizer"]
    test_ticket_sale.status = TicketSaleStatus.refund_requested
    await db_session.flush()
    result = await sales_svc.reject_refund(
        db_session,
        event_id=test_event_approved.id,
        ticket_sale_id=test_ticket_sale.id,
        user=organizer,
    )
    assert result.status == TicketSaleStatus.purchased


@pytest.mark.asyncio
async def test_reject_refund_not_requested(db_session, test_event_approved, test_ticket_sale, test_users):
    """Cannot reject non-requested refund."""
    organizer = test_users["organizer"]
    with pytest.raises(ConflictError, match="refund-requested"):
        await sales_svc.reject_refund(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=test_ticket_sale.id,
            user=organizer,
        )


@pytest.mark.asyncio
async def test_list_refund_requests(db_session, test_event_approved, test_ticket_sale):
    """List refund requests for event."""
    test_ticket_sale.status = TicketSaleStatus.refund_requested
    await db_session.flush()
    result = await sales_svc.list_refund_requests(db_session, event_id=test_event_approved.id)
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_refund_all_tickets(db_session, test_event_approved, test_ticket_sale):
    """Refund all tickets for event."""
    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        count = await sales_svc.refund_all_tickets_for_event(
            db_session, event_id=test_event_approved.id
        )
    assert count >= 1


# ===========================================================================
# SALES: waitlisted ticket operations
# ===========================================================================

@pytest.mark.asyncio
async def test_list_waitlisted_tickets(db_session, test_event_approved, test_ticket_tier, test_users):
    """List waitlisted tickets."""
    # Create a waitlisted ticket
    customer = test_users["customer"]
    sale = TicketSale(
        event_id=test_event_approved.id,
        user_id=customer.id,
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="TKT-WAIT-001",
        receipt_number="TKT-WAIT-REC",
        amount_paid_cents=0,
        status=TicketSaleStatus.waitlisted,
    )
    db_session.add(sale)
    await db_session.flush()
    result = await sales_svc.list_event_waitlisted_tickets(
        db_session, event_id=test_event_approved.id
    )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_approve_waitlisted_ticket(db_session, test_event_approved, test_ticket_tier, test_users):
    """Organizer approves waitlisted ticket."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    sale = TicketSale(
        event_id=test_event_approved.id,
        user_id=customer.id,
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="TKT-WAIT-002",
        receipt_number="TKT-WAIT-REC2",
        amount_paid_cents=0,
        status=TicketSaleStatus.waitlisted,
    )
    db_session.add(sale)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await sales_svc.approve_waitlisted_ticket(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=sale.id,
            user=organizer,
        )
    assert result.status == TicketSaleStatus.purchased


@pytest.mark.asyncio
async def test_reject_waitlisted_ticket(db_session, test_event_approved, test_ticket_tier, test_users):
    """Organizer rejects waitlisted ticket."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    sale = TicketSale(
        event_id=test_event_approved.id,
        user_id=customer.id,
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="TKT-WAIT-003",
        receipt_number="TKT-WAIT-REC3",
        amount_paid_cents=0,
        status=TicketSaleStatus.waitlisted,
    )
    db_session.add(sale)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await sales_svc.reject_waitlisted_ticket(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=sale.id,
            user=organizer,
        )
    assert result.status == TicketSaleStatus.cancelled


# ===========================================================================
# SALES: scan_ticket
# ===========================================================================

@pytest.mark.asyncio
async def test_scan_ticket(db_session, test_event_approved, test_ticket_sale, test_users):
    """Scan ticket successfully."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        sale, already_scanned = await sales_svc.scan_ticket(
            db_session,
            event_id=test_event_approved.id,
            ticket_code=test_ticket_sale.ticket_code,
            scanned_by_user=organizer,
        )
    assert not already_scanned
    assert sale.scanned_at is not None


@pytest.mark.asyncio
async def test_scan_ticket_already_scanned(db_session, test_event_approved, test_ticket_sale, test_users):
    """Scanning already scanned ticket returns already_scanned=True."""
    organizer = test_users["organizer"]
    test_ticket_sale.scanned_at = datetime.now(timezone.utc)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        sale, already_scanned = await sales_svc.scan_ticket(
            db_session,
            event_id=test_event_approved.id,
            ticket_code=test_ticket_sale.ticket_code,
            scanned_by_user=organizer,
        )
    assert already_scanned


@pytest.mark.asyncio
async def test_scan_ticket_not_found(db_session, test_event_approved, test_users):
    """Scan non-existent ticket code."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(NotFoundError, match="Ticket"):
            await sales_svc.scan_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_code="INVALID-CODE",
                scanned_by_user=organizer,
            )


@pytest.mark.asyncio
async def test_scan_ticket_forbidden(db_session, test_event_approved, test_ticket_sale, test_users):
    """Customer cannot scan tickets."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ForbiddenError):
            await sales_svc.scan_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_code=test_ticket_sale.ticket_code,
                scanned_by_user=customer,
            )


# ===========================================================================
# SALES: admin lists
# ===========================================================================

@pytest.mark.asyncio
async def test_list_all_ticket_sales_admin(db_session, test_ticket_sale, test_users):
    """Admin lists all ticket sales."""
    items, total = await sales_svc.list_all_ticket_sales_for_admin(db_session)
    assert total >= 1
    assert len(items) >= 1


@pytest.mark.asyncio
async def test_list_all_ticket_sales_admin_search(db_session, test_ticket_sale, test_users):
    """Admin searches ticket sales."""
    items, total = await sales_svc.list_all_ticket_sales_for_admin(
        db_session, search="Test"
    )
    assert isinstance(total, int)


@pytest.mark.asyncio
async def test_list_tickets_for_user_admin(db_session, test_ticket_sale, test_users):
    """Admin lists user's tickets."""
    customer = test_users["customer"]
    result = await sales_svc.list_tickets_for_user_admin(
        db_session, user_id=customer.id
    )
    assert len(result) >= 1
