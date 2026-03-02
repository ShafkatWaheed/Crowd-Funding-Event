"""
Extended ticket tests: refund flow, waitlist approve/reject, list operations,
receipt, stats, ticket sales for organizer/admin.
"""
import pytest
from datetime import datetime, timezone
from unittest.mock import patch, AsyncMock

from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier


# ---------------------------------------------------------------------------
# Refund flow
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_request_refund(client, db_session, test_event_approved, test_ticket_sale, auth_headers_customer):
    """Customer requests refund → refund_requested status."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/tickets/{test_ticket_sale.id}/refund",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "refund_requested"


@pytest.mark.asyncio
async def test_request_refund_already_scanned(client, db_session, test_event_approved, test_ticket_sale, auth_headers_customer):
    """Cannot refund scanned ticket."""
    test_ticket_sale.scanned_at = datetime.now(timezone.utc)
    await db_session.commit()
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/tickets/{test_ticket_sale.id}/refund",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_approve_refund(client, db_session, test_event_approved, test_ticket_sale, auth_headers_organizer, auth_headers_customer):
    """Organizer approves refund request."""
    test_ticket_sale.status = TicketSaleStatus.refund_requested
    await db_session.commit()
    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        resp = await client.post(
            f"/api/v1/events/{test_event_approved.id}/tickets/{test_ticket_sale.id}/approve-refund",
            headers=auth_headers_organizer,
        )
    assert resp.status_code == 200
    assert resp.json()["status"] in ("refund_processing", "refunded")


@pytest.mark.asyncio
async def test_reject_refund(client, db_session, test_event_approved, test_ticket_sale, auth_headers_organizer):
    """Organizer rejects refund → back to purchased."""
    test_ticket_sale.status = TicketSaleStatus.refund_requested
    await db_session.commit()
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/tickets/{test_ticket_sale.id}/reject-refund",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "purchased"


@pytest.mark.asyncio
async def test_reject_refund_wrong_status(client, db_session, test_event_approved, test_ticket_sale, auth_headers_organizer):
    """Cannot reject if not refund_requested."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/tickets/{test_ticket_sale.id}/reject-refund",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 409


# ---------------------------------------------------------------------------
# Waitlist ticket approve/reject
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_waitlisted_ticket_approve(client, db_session, test_event_approved, test_ticket_tier, test_users, auth_headers_organizer):
    """Organizer approves waitlisted ticket."""
    sale = TicketSale(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="WL-001",
        receipt_number="WL-REC-001",
        amount_paid_cents=2500,
        status=TicketSaleStatus.waitlisted,
    )
    db_session.add(sale)
    await db_session.commit()
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/waitlisted-tickets/{sale.id}/approve",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "purchased"


@pytest.mark.asyncio
async def test_waitlisted_ticket_reject(client, db_session, test_event_approved, test_ticket_tier, test_users, auth_headers_organizer):
    """Organizer rejects waitlisted ticket."""
    sale = TicketSale(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="WL-002",
        receipt_number="WL-REC-002",
        amount_paid_cents=2500,
        status=TicketSaleStatus.waitlisted,
    )
    db_session.add(sale)
    await db_session.commit()
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/waitlisted-tickets/{sale.id}/reject",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "cancelled"


# ---------------------------------------------------------------------------
# List operations
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_my_tickets(client, db_session, test_ticket_sale, auth_headers_customer):
    """Customer lists their tickets."""
    resp = await client.get("/api/v1/me/tickets", headers=auth_headers_customer)
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


@pytest.mark.asyncio
async def test_list_event_ticket_sales(client, db_session, test_event_approved, test_ticket_sale, auth_headers_organizer):
    """Organizer lists ticket sales for event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-sales",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_ticket_sales_stats(client, db_session, test_event_approved, test_ticket_sale, auth_headers_organizer):
    """Ticket sales stats endpoint."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-sales-stats",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "total_sold" in data
    assert data["total_sold"] >= 1


@pytest.mark.asyncio
async def test_ticket_receipt(client, db_session, test_event_approved, test_ticket_sale, auth_headers_customer):
    """Customer gets ticket receipt."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/tickets/{test_ticket_sale.id}/receipt",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_list_waitlisted_tickets(client, db_session, test_event_approved, auth_headers_organizer):
    """Organizer lists waitlisted tickets (may be empty)."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/waitlisted-tickets",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_list_scanned_tickets(client, db_session, test_event_approved, auth_headers_organizer):
    """Organizer lists scanned tickets."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-tickets",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_list_refund_requests(client, db_session, test_event_approved, auth_headers_organizer):
    """Organizer lists refund requests."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/refund-requests",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_organizer_ticket_sales(client, db_session, test_event_approved, test_ticket_sale, auth_headers_organizer):
    """Organizer lists all their ticket sales."""
    resp = await client.get("/api/v1/me/organizer-ticket-sales", headers=auth_headers_organizer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_organizer_refund_requests(client, db_session, test_event_approved, test_ticket_sale, auth_headers_organizer):
    """Organizer lists refund requests across events."""
    resp = await client.get("/api/v1/me/organizer-refund-requests", headers=auth_headers_organizer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_capacity_info(client, db_session, test_event_approved, auth_headers_organizer):
    """Capacity info endpoint."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/capacity-info",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
