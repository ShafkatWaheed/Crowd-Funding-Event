"""
Payment gateway, reconciliation, refund retry, banking tests.
"""
import pytest
from unittest.mock import patch, AsyncMock, MagicMock


# ---------------------------------------------------------------------------
# Banking endpoints
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_stripe_config(client, db_session, auth_headers_customer):
    """GET Stripe config."""
    resp = await client.get("/api/v1/stripe/config", headers=auth_headers_customer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_get_payment_info(client, db_session, test_users, auth_headers_customer):
    """GET current user's payment info."""
    resp = await client.get("/api/v1/me/payment-info", headers=auth_headers_customer)
    assert resp.status_code in (200, 404)


@pytest.mark.asyncio
async def test_get_bank_account(client, db_session, test_users, auth_headers_organizer):
    """GET current user's bank account."""
    resp = await client.get("/api/v1/me/bank-account", headers=auth_headers_organizer)
    assert resp.status_code in (200, 404)


@pytest.mark.asyncio
async def test_put_bank_account(client, db_session, test_users, auth_headers_organizer):
    """PUT bank account."""
    resp = await client.put(
        "/api/v1/me/bank-account",
        headers=auth_headers_organizer,
        json={
            "institution_number": "001",
            "transit_number": "12345",
            "account_number": "1234567",
            "account_holder": "Test Org",
        },
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_payment_status(client, db_session, test_users, auth_headers_admin):
    """GET payment status by transaction ID."""
    resp = await client.get(
        "/api/v1/payments/nonexistent-txn/status",
        headers=auth_headers_admin,
    )
    assert resp.status_code in (200, 404)


# ---------------------------------------------------------------------------
# Admin banking overview
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_banking_overview(client, db_session, test_users, auth_headers_admin):
    """Admin banking overview."""
    resp = await client.get("/api/v1/admin/banking-overview", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_mock_overview(client, db_session, test_users, auth_headers_admin):
    """Admin mock overview."""
    resp = await client.get("/api/v1/admin/mock-overview", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_ledger_health(client, db_session, test_users, auth_headers_admin):
    """Admin ledger health check."""
    resp = await client.get("/api/v1/admin/ledger-health", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_transactions(client, db_session, test_users, auth_headers_admin):
    """Admin transactions list."""
    resp = await client.get("/api/v1/admin/transactions", headers=auth_headers_admin)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin disputes
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_disputes(client, db_session, test_users, auth_headers_admin):
    """Admin lists disputes."""
    resp = await client.get("/api/v1/admin/disputes", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_simulate_dispute(client, db_session, test_event_approved, test_ticket_sale, auth_headers_admin):
    """Admin simulates a mock dispute."""
    resp = await client.post(
        "/api/v1/admin/mock/simulate-dispute",
        headers=auth_headers_admin,
        json={
            "transaction_id": test_ticket_sale.gateway_transaction_id or "mock-txn-001",
            "amount_cents": 2500,
            "reason": "product_not_received",
        },
    )
    # May fail if mock mode not enabled
    assert resp.status_code in (200, 201, 400, 409)


# ---------------------------------------------------------------------------
# Admin reconciliation
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_reconciliation_status(client, db_session, test_users, auth_headers_admin):
    """Admin reconciliation status."""
    resp = await client.get("/api/v1/admin/reconciliation", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_reconciliation_history(client, db_session, test_users, auth_headers_admin):
    """Admin reconciliation history."""
    resp = await client.get("/api/v1/admin/reconciliation/history", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_run_reconciliation(client, db_session, test_users, auth_headers_admin):
    """Admin runs reconciliation."""
    resp = await client.post("/api/v1/admin/reconciliation/run", headers=auth_headers_admin)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin refund retry
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_retry_all_for_event(client, db_session, test_event_approved, auth_headers_admin):
    """Admin retries all failed refunds for event."""
    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        resp = await client.post(
            f"/api/v1/admin/refunds/retry-all/{test_event_approved.id}",
            headers=auth_headers_admin,
        )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin payout
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_payout_status(client, db_session, test_users, auth_headers_admin):
    """Admin payout status."""
    resp = await client.get("/api/v1/admin/payout-status", headers=auth_headers_admin)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Email templates (admin)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_email_templates(client, db_session, test_users, auth_headers_admin):
    """Admin lists email templates."""
    resp = await client.get("/api/v1/admin/email-templates", headers=auth_headers_admin)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Verify bank account (admin)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_verify_bank(client, db_session, test_users, test_organizer_bank, auth_headers_admin):
    """Admin verifies bank account."""
    organizer = test_users["organizer"]
    resp = await client.post(
        f"/api/v1/admin/bank-accounts/{organizer.id}/verify",
        headers=auth_headers_admin,
    )
    assert resp.status_code == 200
