"""
Service-level tests for app/services/ticket/sales.py — Phase 3.

Covers list/query functions, status transitions (waitlist approve/reject,
refund request/approve/reject), and ticket scanning. Deliberately skips
purchase_ticket (complex, already partially covered elsewhere).
"""
import pytest
from datetime import datetime, timezone
from unittest.mock import patch, AsyncMock

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.event import Event, EventStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
from app.models.user import User, UserRole

from app.services.ticket import sales as sales_svc


# ---------------------------------------------------------------------------
# Helper: create ticket sales without going through the full purchase flow
# ---------------------------------------------------------------------------

_ticket_counter = 0


async def _make_sale(
    db,
    event: Event,
    user: User,
    tier: TicketTier,
    *,
    status: TicketSaleStatus = TicketSaleStatus.purchased,
    scanned: bool = False,
) -> TicketSale:
    global _ticket_counter
    _ticket_counter += 1
    sale = TicketSale(
        event_id=event.id,
        user_id=user.id,
        ticket_tier_id=tier.id,
        ticket_code=f"TKT-{event.id}-{user.id}-{_ticket_counter}",
        receipt_number=f"RCP-{event.id}-{user.id}-{_ticket_counter}",
        amount_paid_cents=tier.price_cents,
        commission_cents=tier.price_cents * 10 // 100,
        net_to_organizer_cents=tier.price_cents * 90 // 100,
        status=status,
        gateway_transaction_id=f"txn-{_ticket_counter}",
    )
    if scanned:
        sale.scanned_at = datetime.now(timezone.utc)
    db.add(sale)
    await db.flush()
    return sale


# Shorthand: patch auto_transition_status so get_or_404 doesn't do real
# time-based transitions or hit platform_settings during tests.
_patch_auto = lambda: patch(
    "app.services.event.crud.auto_transition_status",
    new_callable=AsyncMock,
    side_effect=lambda db, e: e,
)


# ===================================================================
# 1. get_ticket_sold_counts_for_events
# ===================================================================


@pytest.mark.asyncio
async def test_sold_counts_empty_list(db_session):
    """Empty event_ids returns empty dict."""
    result = await sales_svc.get_ticket_sold_counts_for_events(db_session, event_ids=[])
    assert result == {}


@pytest.mark.asyncio
async def test_sold_counts_no_tickets(db_session, test_event_approved):
    """Event with no purchased tickets returns 0 count (absent key)."""
    result = await sales_svc.get_ticket_sold_counts_for_events(
        db_session, event_ids=[test_event_approved.id]
    )
    # No purchased tickets yet, so event_id key won't appear
    assert result.get(test_event_approved.id, 0) == 0


@pytest.mark.asyncio
async def test_sold_counts_with_tickets(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Purchased tickets counted; waitlisted tickets are not."""
    customer = test_users["customer"]
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )

    result = await sales_svc.get_ticket_sold_counts_for_events(
        db_session, event_ids=[test_event_approved.id]
    )
    assert result[test_event_approved.id] == 2


# ===================================================================
# 2. get_ticket_sales_stats
# ===================================================================


@pytest.mark.asyncio
async def test_sales_stats_no_sales(db_session, test_event_approved):
    """No sales returns zeros."""
    stats = await sales_svc.get_ticket_sales_stats(
        db_session, event_id=test_event_approved.id
    )
    assert stats == {"total_sold": 0, "total_scanned": 0}


@pytest.mark.asyncio
async def test_sales_stats_with_sales_and_scanned(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Returns correct total_sold and total_scanned."""
    customer = test_users["customer"]
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier, scanned=True
    )

    stats = await sales_svc.get_ticket_sales_stats(
        db_session, event_id=test_event_approved.id
    )
    assert stats["total_sold"] == 2
    assert stats["total_scanned"] == 1


# ===================================================================
# 3. get_ticket_receipt
# ===================================================================


@pytest.mark.asyncio
async def test_receipt_found(db_session, test_ticket_sale, test_users):
    """Load receipt for existing sale."""
    sale = await sales_svc.get_ticket_receipt(
        db_session, sale_id=test_ticket_sale.id
    )
    assert sale.id == test_ticket_sale.id


@pytest.mark.asyncio
async def test_receipt_not_found(db_session):
    """Non-existent sale raises NotFoundError."""
    with pytest.raises(NotFoundError, match="TicketSale"):
        await sales_svc.get_ticket_receipt(db_session, sale_id=999999)


@pytest.mark.asyncio
async def test_receipt_wrong_user(db_session, test_ticket_sale, test_users):
    """Requesting another user's receipt raises ForbiddenError."""
    organizer = test_users["organizer"]
    with pytest.raises(ForbiddenError, match="own"):
        await sales_svc.get_ticket_receipt(
            db_session, sale_id=test_ticket_sale.id, user_id=organizer.id
        )


# ===================================================================
# 4. list_my_tickets
# ===================================================================


@pytest.mark.asyncio
async def test_list_my_tickets_empty(db_session, test_users):
    """User with no tickets gets empty list."""
    result = await sales_svc.list_my_tickets(
        db_session, user_id=test_users["organizer"].id
    )
    assert result == []


@pytest.mark.asyncio
async def test_list_my_tickets_with_sales(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """User sees their purchased and waitlisted tickets."""
    customer = test_users["customer"]
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )

    result = await sales_svc.list_my_tickets(db_session, user_id=customer.id)
    assert len(result) == 2


@pytest.mark.asyncio
async def test_list_my_tickets_sort_by_oldest(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """sort_by='oldest' returns tickets in ascending created_at order."""
    customer = test_users["customer"]
    s1 = await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    s2 = await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    result = await sales_svc.list_my_tickets(
        db_session, user_id=customer.id, sort_by="oldest"
    )
    assert result[0].id <= result[-1].id


# ===================================================================
# 5. list_tickets_for_user_admin
# ===================================================================


@pytest.mark.asyncio
async def test_list_tickets_for_user_admin_empty(db_session, test_users):
    """Admin list for user with no tickets returns empty."""
    result = await sales_svc.list_tickets_for_user_admin(
        db_session, user_id=test_users["organizer"].id
    )
    assert result == []


@pytest.mark.asyncio
async def test_list_tickets_for_user_admin_with_tickets(
    db_session, test_ticket_sale, test_users
):
    """Admin list returns tickets for user (all statuses)."""
    result = await sales_svc.list_tickets_for_user_admin(
        db_session, user_id=test_users["customer"].id
    )
    assert len(result) >= 1


# ===================================================================
# 6. list_event_ticket_sales
# ===================================================================


@pytest.mark.asyncio
async def test_list_event_ticket_sales(
    db_session, test_event_approved, test_ticket_sale
):
    """Returns ticket sales for an event."""
    with _patch_auto():
        result = await sales_svc.list_event_ticket_sales(
            db_session, event_id=test_event_approved.id
        )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_event_ticket_sales_not_found(db_session):
    """Non-existent event raises NotFoundError."""
    with pytest.raises(NotFoundError):
        await sales_svc.list_event_ticket_sales(db_session, event_id=999999)


# ===================================================================
# 7. list_event_scanned_ticket_sales
# ===================================================================


@pytest.mark.asyncio
async def test_list_scanned_none(db_session, test_event_approved, test_ticket_sale):
    """No scanned tickets returns empty list."""
    with _patch_auto():
        result = await sales_svc.list_event_scanned_ticket_sales(
            db_session, event_id=test_event_approved.id
        )
    assert result == []


@pytest.mark.asyncio
async def test_list_scanned_with_scanned(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Only scanned tickets are returned."""
    customer = test_users["customer"]
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier, scanned=True
    )

    with _patch_auto():
        result = await sales_svc.list_event_scanned_ticket_sales(
            db_session, event_id=test_event_approved.id
        )
    assert len(result) == 1
    assert result[0].scanned_at is not None


# ===================================================================
# 8. list_organizer_ticket_sales
# ===================================================================


@pytest.mark.asyncio
async def test_list_organizer_ticket_sales_basic(
    db_session, test_event_approved, test_ticket_sale, test_users
):
    """Organizer sees their event's sales."""
    organizer = test_users["organizer"]
    result = await sales_svc.list_organizer_ticket_sales(
        db_session, organizer_id=organizer.id
    )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_organizer_ticket_sales_scanned_only(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """scanned_only=True filters to scanned tickets."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier, scanned=True
    )

    result = await sales_svc.list_organizer_ticket_sales(
        db_session, organizer_id=organizer.id, scanned_only=True
    )
    assert all(s.scanned_at is not None for s in result)


@pytest.mark.asyncio
async def test_list_organizer_ticket_sales_event_id_filter(
    db_session, test_event_approved, test_ticket_sale, test_users
):
    """event_id filter limits to specific event."""
    organizer = test_users["organizer"]
    result = await sales_svc.list_organizer_ticket_sales(
        db_session, organizer_id=organizer.id, event_id=test_event_approved.id
    )
    assert all(s.event_id == test_event_approved.id for s in result)


# ===================================================================
# 9. list_organizer_refund_requests
# ===================================================================


@pytest.mark.asyncio
async def test_list_organizer_refund_requests_empty(db_session, test_users):
    """No refund requests returns empty list."""
    organizer = test_users["organizer"]
    result = await sales_svc.list_organizer_refund_requests(
        db_session, organizer_id=organizer.id
    )
    assert result == []


@pytest.mark.asyncio
async def test_list_organizer_refund_requests_with_requests(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Returns only refund_requested tickets for organizer's events."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.refund_requested,
    )
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    result = await sales_svc.list_organizer_refund_requests(
        db_session, organizer_id=organizer.id
    )
    assert len(result) == 1
    assert result[0].status == TicketSaleStatus.refund_requested


# ===================================================================
# 10. list_all_ticket_sales_for_admin
# ===================================================================


@pytest.mark.asyncio
async def test_admin_list_no_results(db_session):
    """Empty DB returns ([], 0)."""
    items, total = await sales_svc.list_all_ticket_sales_for_admin(db_session)
    assert items == []
    assert total == 0


@pytest.mark.asyncio
async def test_admin_list_with_results(
    db_session, test_event_approved, test_ticket_sale
):
    """Returns ticket sales and a total count."""
    items, total = await sales_svc.list_all_ticket_sales_for_admin(db_session)
    assert total >= 1
    assert len(items) >= 1


@pytest.mark.asyncio
async def test_admin_list_status_filter(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Status filter limits results to that status."""
    customer = test_users["customer"]
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    items, total = await sales_svc.list_all_ticket_sales_for_admin(
        db_session, status="waitlisted"
    )
    assert all(s.status == TicketSaleStatus.waitlisted for s in items)


# ===================================================================
# 11. list_event_waitlisted_tickets
# ===================================================================


@pytest.mark.asyncio
async def test_waitlisted_none(db_session, test_event_approved, test_ticket_sale):
    """No waitlisted tickets for event."""
    with _patch_auto():
        result = await sales_svc.list_event_waitlisted_tickets(
            db_session, event_id=test_event_approved.id
        )
    assert result == []


@pytest.mark.asyncio
async def test_waitlisted_with_tickets(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Only waitlisted tickets returned."""
    customer = test_users["customer"]
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )

    with _patch_auto():
        result = await sales_svc.list_event_waitlisted_tickets(
            db_session, event_id=test_event_approved.id
        )
    assert len(result) == 1
    assert result[0].status == TicketSaleStatus.waitlisted


# ===================================================================
# 12. approve_waitlisted_ticket
# ===================================================================


@pytest.mark.asyncio
async def test_approve_waitlisted_success(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Organizer approves waitlisted -> purchased."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )

    with _patch_auto():
        result = await sales_svc.approve_waitlisted_ticket(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=sale.id,
            user=organizer,
        )
    assert result.status == TicketSaleStatus.purchased


@pytest.mark.asyncio
async def test_approve_waitlisted_not_found(
    db_session, test_event_approved, test_users
):
    """Approving non-existent ticket raises NotFoundError."""
    with _patch_auto():
        with pytest.raises(NotFoundError):
            await sales_svc.approve_waitlisted_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_sale_id=999999,
                user=test_users["organizer"],
            )


@pytest.mark.asyncio
async def test_approve_waitlisted_not_waitlisted(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Approving a purchased ticket raises ConflictError."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    with _patch_auto():
        with pytest.raises(ConflictError, match="waitlisted"):
            await sales_svc.approve_waitlisted_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_sale_id=sale.id,
                user=organizer,
            )


@pytest.mark.asyncio
async def test_approve_waitlisted_not_organizer(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Non-organizer cannot approve."""
    customer = test_users["customer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )

    with _patch_auto():
        with pytest.raises(ForbiddenError):
            await sales_svc.approve_waitlisted_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_sale_id=sale.id,
                user=customer,
            )


# ===================================================================
# 13. reject_waitlisted_ticket
# ===================================================================


@pytest.mark.asyncio
async def test_reject_waitlisted_success(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Organizer rejects waitlisted -> cancelled."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )

    with _patch_auto():
        result = await sales_svc.reject_waitlisted_ticket(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=sale.id,
            user=organizer,
        )
    assert result.status == TicketSaleStatus.cancelled


@pytest.mark.asyncio
async def test_reject_waitlisted_not_organizer(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Non-organizer cannot reject."""
    customer = test_users["customer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )

    with _patch_auto():
        with pytest.raises(ForbiddenError):
            await sales_svc.reject_waitlisted_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_sale_id=sale.id,
                user=customer,
            )


# ===================================================================
# 14. request_refund
# ===================================================================


@pytest.mark.asyncio
async def test_request_refund_success(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Customer requests refund on a purchased ticket."""
    customer = test_users["customer"]
    sale = await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    result = await sales_svc.request_refund(
        db_session,
        event_id=test_event_approved.id,
        ticket_sale_id=sale.id,
        user=customer,
    )
    assert result.status == TicketSaleStatus.refund_requested


@pytest.mark.asyncio
async def test_request_refund_not_found(
    db_session, test_event_approved, test_users
):
    """Refund on non-existent ticket raises NotFoundError."""
    with pytest.raises(NotFoundError):
        await sales_svc.request_refund(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=999999,
            user=test_users["customer"],
        )


@pytest.mark.asyncio
async def test_request_refund_idempotent(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Requesting refund again on refund_requested ticket returns the sale."""
    customer = test_users["customer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.refund_requested,
    )

    result = await sales_svc.request_refund(
        db_session,
        event_id=test_event_approved.id,
        ticket_sale_id=sale.id,
        user=customer,
    )
    assert result.status == TicketSaleStatus.refund_requested


@pytest.mark.asyncio
async def test_request_refund_not_purchased(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Refund on waitlisted ticket raises ConflictError."""
    customer = test_users["customer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.waitlisted,
    )

    with pytest.raises(ConflictError, match="purchased"):
        await sales_svc.request_refund(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=sale.id,
            user=customer,
        )


@pytest.mark.asyncio
async def test_request_refund_scanned_ticket(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Refund on already-scanned ticket raises ConflictError."""
    customer = test_users["customer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier, scanned=True
    )

    with pytest.raises(ConflictError, match="[Ss]canned"):
        await sales_svc.request_refund(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=sale.id,
            user=customer,
        )


# ===================================================================
# 15. approve_refund
# ===================================================================


@pytest.mark.asyncio
async def test_approve_refund_success(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Organizer approves refund -> refund_processing and enqueues task."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.refund_requested,
    )

    with _patch_auto():
        with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock) as mock_enqueue:
            result = await sales_svc.approve_refund(
                db_session,
                event_id=test_event_approved.id,
                ticket_sale_id=sale.id,
                user=organizer,
            )
    assert result.status == TicketSaleStatus.refund_processing
    mock_enqueue.assert_awaited_once_with("process_ticket_refund", sale.id)


@pytest.mark.asyncio
async def test_approve_refund_not_found(
    db_session, test_event_approved, test_users
):
    """Approving refund for non-existent ticket raises NotFoundError."""
    with _patch_auto():
        with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
            with pytest.raises(NotFoundError):
                await sales_svc.approve_refund(
                    db_session,
                    event_id=test_event_approved.id,
                    ticket_sale_id=999999,
                    user=test_users["organizer"],
                )


@pytest.mark.asyncio
async def test_approve_refund_wrong_status(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Approving refund on purchased (not refund_requested) raises ConflictError."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    with _patch_auto():
        with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
            with pytest.raises(ConflictError, match="refund-requested"):
                await sales_svc.approve_refund(
                    db_session,
                    event_id=test_event_approved.id,
                    ticket_sale_id=sale.id,
                    user=organizer,
                )


@pytest.mark.asyncio
async def test_approve_refund_not_organizer(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Non-organizer cannot approve refund."""
    customer = test_users["customer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.refund_requested,
    )

    with _patch_auto():
        with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
            with pytest.raises(ForbiddenError):
                await sales_svc.approve_refund(
                    db_session,
                    event_id=test_event_approved.id,
                    ticket_sale_id=sale.id,
                    user=customer,
                )


# ===================================================================
# 16. reject_refund
# ===================================================================


@pytest.mark.asyncio
async def test_reject_refund_success(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Organizer rejects refund -> back to purchased."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.refund_requested,
    )

    with _patch_auto():
        result = await sales_svc.reject_refund(
            db_session,
            event_id=test_event_approved.id,
            ticket_sale_id=sale.id,
            user=organizer,
        )
    assert result.status == TicketSaleStatus.purchased


@pytest.mark.asyncio
async def test_reject_refund_wrong_status(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Rejecting refund on purchased ticket raises ConflictError."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    with _patch_auto():
        with pytest.raises(ConflictError, match="refund-requested"):
            await sales_svc.reject_refund(
                db_session,
                event_id=test_event_approved.id,
                ticket_sale_id=sale.id,
                user=organizer,
            )


@pytest.mark.asyncio
async def test_reject_refund_not_organizer(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Non-organizer cannot reject refund."""
    customer = test_users["customer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.refund_requested,
    )

    with _patch_auto():
        with pytest.raises(ForbiddenError):
            await sales_svc.reject_refund(
                db_session,
                event_id=test_event_approved.id,
                ticket_sale_id=sale.id,
                user=customer,
            )


# ===================================================================
# 17. list_refund_requests
# ===================================================================


@pytest.mark.asyncio
async def test_list_refund_requests_none(db_session, test_event_approved):
    """No refund_requested tickets for event returns empty list."""
    result = await sales_svc.list_refund_requests(
        db_session, event_id=test_event_approved.id
    )
    assert result == []


@pytest.mark.asyncio
async def test_list_refund_requests_with_requests(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Only refund_requested tickets returned."""
    customer = test_users["customer"]
    await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)
    await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier,
        status=TicketSaleStatus.refund_requested,
    )

    result = await sales_svc.list_refund_requests(
        db_session, event_id=test_event_approved.id
    )
    assert len(result) == 1
    assert result[0].status == TicketSaleStatus.refund_requested


# ===================================================================
# 18. scan_ticket
# ===================================================================


@pytest.mark.asyncio
async def test_scan_ticket_success(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """First scan sets scanned_at and returns already_scanned=False."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    with _patch_auto():
        with patch(
            "app.services.event.record_customer_attendance",
            new_callable=AsyncMock,
        ):
            result_sale, already_scanned = await sales_svc.scan_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_code=sale.ticket_code,
                scanned_by_user=organizer,
            )
    assert not already_scanned
    assert result_sale.scanned_at is not None


@pytest.mark.asyncio
async def test_scan_ticket_already_scanned(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Second scan returns already_scanned=True."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    sale = await _make_sale(
        db_session, test_event_approved, customer, test_ticket_tier, scanned=True
    )

    with _patch_auto():
        with patch(
            "app.services.event.record_customer_attendance",
            new_callable=AsyncMock,
        ):
            result_sale, already_scanned = await sales_svc.scan_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_code=sale.ticket_code,
                scanned_by_user=organizer,
            )
    assert already_scanned


@pytest.mark.asyncio
async def test_scan_ticket_wrong_code(
    db_session, test_event_approved, test_users
):
    """Invalid ticket code raises NotFoundError."""
    organizer = test_users["organizer"]
    with _patch_auto():
        with pytest.raises(NotFoundError, match="[Tt]icket"):
            await sales_svc.scan_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_code="INVALID-CODE",
                scanned_by_user=organizer,
            )


@pytest.mark.asyncio
async def test_scan_ticket_not_organizer(
    db_session, test_event_approved, test_ticket_tier, test_users
):
    """Non-organizer cannot scan tickets."""
    customer = test_users["customer"]
    sale = await _make_sale(db_session, test_event_approved, customer, test_ticket_tier)

    with _patch_auto():
        with pytest.raises(ForbiddenError):
            await sales_svc.scan_ticket(
                db_session,
                event_id=test_event_approved.id,
                ticket_code=sale.ticket_code,
                scanned_by_user=customer,
            )
