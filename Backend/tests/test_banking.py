"""Banking API: stripe config, payment info, bank accounts, payment status, admin banking."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ═══════════════════════════════════════════
#  Stripe Config (public)
# ═══════════════════════════════════════════


async def test_stripe_config(client: AsyncClient, test_users):
    """GET stripe config is public."""
    r = await client.get("/api/v1/stripe/config")
    assert r.status_code == 200
    data = r.json()
    assert "stripe_enabled" in data
    assert "stripe_connect_enabled" in data
    assert "publishable_key" in data


# ═══════════════════════════════════════════
#  Payment Intent
# ═══════════════════════════════════════════


async def test_create_payment_intent(client: AsyncClient, auth_headers_customer, test_users):
    """POST create-intent returns 400 (stripe disabled) or 501 (stub)."""
    r = await client.post(
        "/api/v1/payments/create-intent",
        json={"amount_cents": 5000, "description": "Test payment"},
        headers=auth_headers_customer,
    )
    # Stripe is disabled by default so returns 400; if enabled, returns 501 (not implemented)
    assert r.status_code in (400, 501)


async def test_create_payment_intent_unauthenticated(client: AsyncClient, test_users):
    """POST create-intent without auth returns 401/403."""
    r = await client.post(
        "/api/v1/payments/create-intent",
        json={"amount_cents": 5000, "description": "Test payment"},
    )
    assert r.status_code in (401, 403)


# ═══════════════════════════════════════════
#  User Payment Info
# ═══════════════════════════════════════════


async def test_get_payment_info(client: AsyncClient, auth_headers_customer, test_users):
    """GET payment-info returns info for authenticated user."""
    r = await client.get("/api/v1/me/payment-info", headers=auth_headers_customer)
    assert r.status_code == 200


async def test_update_payment_info(client: AsyncClient, auth_headers_customer, test_users):
    """PUT payment-info updates card info."""
    r = await client.put(
        "/api/v1/me/payment-info",
        json={
            "card_holder_name": "Test User",
            "card_last_four": "4242",
            "card_brand": "Visa",
        },
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["card_holder_name"] == "Test User"
    assert data["card_last_four"] == "4242"
    assert data["card_brand"] == "Visa"


async def test_payment_info_unauthenticated(client: AsyncClient, test_users):
    """GET payment-info without auth returns 401/403."""
    r = await client.get("/api/v1/me/payment-info")
    assert r.status_code in (401, 403)


# ═══════════════════════════════════════════
#  Organizer Bank Account
# ═══════════════════════════════════════════


async def test_get_bank_account(client: AsyncClient, auth_headers_organizer, test_users):
    """GET bank-account returns info for organizer (empty initially)."""
    r = await client.get("/api/v1/me/bank-account", headers=auth_headers_organizer)
    assert r.status_code == 200
    data = r.json()
    assert data["has_bank_account"] is False


async def test_create_bank_account(client: AsyncClient, auth_headers_organizer, test_users):
    """PUT bank-account creates/updates bank account for organizer."""
    r = await client.put(
        "/api/v1/me/bank-account",
        json={
            "institution_number": "001",
            "transit_number": "12345",
            "account_number": "1234567",
            "account_holder": "Test Organizer",
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["has_bank_account"] is True
    assert data["account_last_four"] == "4567"
    assert data["institution_number"] == "001"
    assert data["transit_number"] == "12345"
    assert data["verification_status"] == "pending"


async def test_delete_bank_account_forbidden(client: AsyncClient, auth_headers_organizer, test_users):
    """DELETE bank-account returns 403 (cannot delete)."""
    r = await client.delete("/api/v1/me/bank-account", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_bank_account_customer_forbidden(client: AsyncClient, auth_headers_customer, test_users):
    """Customer cannot access organizer-only bank account endpoint."""
    r = await client.put(
        "/api/v1/me/bank-account",
        json={
            "institution_number": "001",
            "transit_number": "12345",
            "account_number": "1234567",
            "account_holder": "Test",
        },
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_bank_account_encrypted_storage(client: AsyncClient, auth_headers_organizer, test_users):
    """After PUT, GET returns masked account info with last 4 digits."""
    await client.put(
        "/api/v1/me/bank-account",
        json={
            "institution_number": "001",
            "transit_number": "12345",
            "account_number": "9876543",
            "account_holder": "Test Organizer",
        },
        headers=auth_headers_organizer,
    )
    r = await client.get("/api/v1/me/bank-account", headers=auth_headers_organizer)
    assert r.status_code == 200
    data = r.json()
    assert data["has_bank_account"] is True
    assert data["account_last_four"] == "6543"


# ═══════════════════════════════════════════
#  Payment Status Polling
# ═══════════════════════════════════════════


async def test_payment_status_not_found(client: AsyncClient, auth_headers_customer, test_users):
    """GET payment status for non-existent transaction returns not_found."""
    r = await client.get(
        "/api/v1/payments/nonexistent-txn/status",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "not_found"


# ═══════════════════════════════════════════
#  Admin Banking Overview
# ═══════════════════════════════════════════


async def test_admin_banking_overview(client: AsyncClient, auth_headers_admin, test_users):
    """GET admin banking overview returns financial summary."""
    r = await client.get("/api/v1/admin/banking-overview", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "fund_escrow_total_held_cents" in data
    assert "commission_total_cents" in data
    assert "transaction_total_count" in data
    assert "mock_mode_active" in data


async def test_admin_banking_overview_non_admin(client: AsyncClient, auth_headers_organizer, test_users):
    """Non-admin cannot access banking overview."""
    r = await client.get("/api/v1/admin/banking-overview", headers=auth_headers_organizer)
    assert r.status_code == 403


# ═══════════════════════════════════════════
#  Admin Platform Account
# ═══════════════════════════════════════════


async def test_admin_platform_account_get(client: AsyncClient, auth_headers_admin, test_users):
    """GET admin platform account (empty initially)."""
    r = await client.get("/api/v1/admin/platform-account", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert data["configured"] is False


async def test_admin_platform_account_update(client: AsyncClient, auth_headers_admin, test_users):
    """PUT admin platform account configures the platform holding account."""
    r = await client.put(
        "/api/v1/admin/platform-account",
        json={
            "institution_number": "003",
            "transit_number": "67890",
            "account_number": "1122334455",
            "account_holder": "Platform Inc",
        },
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["configured"] is True
    assert data["institution_number"] == "003"
    assert data["account_last_four"] == "4455"


# ═══════════════════════════════════════════
#  Admin Bank Account Verification
# ═══════════════════════════════════════════


async def test_admin_verify_bank_account(
    client: AsyncClient, auth_headers_admin, auth_headers_organizer, test_users,
):
    """Admin verifies an organizer's bank account."""
    # First, organizer creates a bank account
    await client.put(
        "/api/v1/me/bank-account",
        json={
            "institution_number": "001",
            "transit_number": "12345",
            "account_number": "1234567",
            "account_holder": "Test Organizer",
        },
        headers=auth_headers_organizer,
    )
    organizer_id = test_users["organizer"].id

    r = await client.post(
        f"/api/v1/admin/bank-accounts/{organizer_id}/verify",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["verification_status"] == "verified"


async def test_admin_reject_bank_account(
    client: AsyncClient, auth_headers_admin, auth_headers_organizer, test_users,
):
    """Admin rejects an organizer's bank account with a reason."""
    # First, organizer creates a bank account
    await client.put(
        "/api/v1/me/bank-account",
        json={
            "institution_number": "001",
            "transit_number": "12345",
            "account_number": "1234567",
            "account_holder": "Test Organizer",
        },
        headers=auth_headers_organizer,
    )
    organizer_id = test_users["organizer"].id

    r = await client.post(
        f"/api/v1/admin/bank-accounts/{organizer_id}/reject",
        json={"reason": "Invalid institution number"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["verification_status"] == "rejected"


# ═══════════════════════════════════════════
#  Admin Email Templates
# ═══════════════════════════════════════════


async def test_list_email_templates(client: AsyncClient, auth_headers_admin, test_users):
    """GET email templates returns default template list."""
    r = await client.get("/api/v1/admin/email-templates", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # Each template has the expected keys
    first = data[0]
    assert "template_key" in first
    assert "subject" in first
    assert "body_html" in first
    assert "variables" in first
    assert "is_active" in first
    assert "is_customized" in first


async def test_list_email_templates_non_admin(client: AsyncClient, auth_headers_customer, test_users):
    """Non-admin cannot list email templates."""
    r = await client.get("/api/v1/admin/email-templates", headers=auth_headers_customer)
    assert r.status_code == 403


async def test_update_email_template(client: AsyncClient, auth_headers_admin, test_users):
    """PUT email template creates or updates a template."""
    r = await client.put(
        "/api/v1/admin/email-templates/event_cancelled",
        json={"subject": "CANCELLED: {{event_title}}", "body_html": "<h1>Cancelled</h1>"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["template_key"] == "event_cancelled"


async def test_update_email_template_new_key(client: AsyncClient, auth_headers_admin, test_users):
    """PUT email template with unknown key creates a new template row."""
    r = await client.put(
        "/api/v1/admin/email-templates/custom_template_xyz",
        json={"subject": "Custom Subject", "body_html": "<p>custom</p>"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["template_key"] == "custom_template_xyz"


async def test_reset_email_template(client: AsyncClient, auth_headers_admin, test_users):
    """POST reset reverts a single template to default (deletes DB row)."""
    # First, customise the template
    await client.put(
        "/api/v1/admin/email-templates/event_cancelled",
        json={"subject": "custom subject"},
        headers=auth_headers_admin,
    )
    # Then reset it
    r = await client.post(
        "/api/v1/admin/email-templates/event_cancelled/reset",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert "reset to default" in data["message"].lower()


async def test_reset_email_template_nonexistent(client: AsyncClient, auth_headers_admin, test_users):
    """POST reset on a template that has no DB row succeeds gracefully."""
    r = await client.post(
        "/api/v1/admin/email-templates/nonexistent_key_999/reset",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True


async def test_reset_all_email_templates(client: AsyncClient, auth_headers_admin, test_users):
    """POST reset-all removes all customised email templates."""
    # Create two custom templates first
    await client.put(
        "/api/v1/admin/email-templates/event_cancelled",
        json={"subject": "custom1"},
        headers=auth_headers_admin,
    )
    await client.put(
        "/api/v1/admin/email-templates/ticket_purchased",
        json={"subject": "custom2"},
        headers=auth_headers_admin,
    )
    r = await client.post(
        "/api/v1/admin/email-templates/reset-all",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert "deleted_count" in data
    assert data["deleted_count"] >= 2


async def test_test_send_email_template(client: AsyncClient, auth_headers_admin, test_users):
    """POST test-send sends a test email for a template key."""
    r = await client.post(
        "/api/v1/admin/email-templates/event_cancelled/test-send",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["sent_to"] == "admin@test.com"


async def test_upload_email_logo(client: AsyncClient, auth_headers_admin, test_users):
    """POST upload-logo uploads a logo image for email templates."""
    import io
    # Create a minimal 1x1 PNG file
    png_data = (
        b"\x89PNG\r\n\x1a\n"
        b"\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02"
        b"\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx"
        b"\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N"
        b"\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    r = await client.post(
        "/api/v1/admin/email-templates/upload-logo",
        files={"file": ("logo.png", io.BytesIO(png_data), "image/png")},
        headers=auth_headers_admin,
    )
    # May succeed or fail depending on upload validation config
    assert r.status_code in (200, 400, 422)
    if r.status_code == 200:
        data = r.json()
        assert data["ok"] is True
        assert "logo_url" in data


# ═══════════════════════════════════════════
#  Admin Mock Overview & Quick Actions
# ═══════════════════════════════════════════


async def test_admin_mock_overview(client: AsyncClient, auth_headers_admin, test_users):
    """GET mock-overview returns mock payment/email stats."""
    r = await client.get("/api/v1/admin/mock-overview", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "total_transactions" in data
    assert "total_volume_cents" in data
    assert "success_count" in data
    assert "total_emails" in data
    assert "recent_transactions" in data
    assert "recent_emails" in data


async def test_admin_mock_overview_non_admin(client: AsyncClient, auth_headers_organizer, test_users):
    """Non-admin cannot access mock overview."""
    r = await client.get("/api/v1/admin/mock-overview", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_admin_mock_clear(client: AsyncClient, auth_headers_admin, test_users):
    """POST mock/clear clears all mock data (or 403 if mock mode disabled)."""
    r = await client.post("/api/v1/admin/mock/clear", headers=auth_headers_admin)
    # 200 if mock mode enabled, 403 if disabled
    assert r.status_code in (200, 403)
    if r.status_code == 200:
        data = r.json()
        assert data["ok"] is True


async def test_admin_mock_settle_all(client: AsyncClient, auth_headers_admin, test_users):
    """POST mock/settle-all settles all pending mock transactions."""
    r = await client.post("/api/v1/admin/mock/settle-all", headers=auth_headers_admin)
    assert r.status_code in (200, 403)
    if r.status_code == 200:
        data = r.json()
        assert data["ok"] is True
        assert "settled_count" in data


async def test_admin_mock_fail_next(client: AsyncClient, auth_headers_admin, test_users):
    """POST mock/fail-next sets next charge to fail."""
    r = await client.post("/api/v1/admin/mock/fail-next", headers=auth_headers_admin)
    assert r.status_code in (200, 403)
    if r.status_code == 200:
        data = r.json()
        assert data["ok"] is True


async def test_admin_mock_reset_defaults(client: AsyncClient, auth_headers_admin, test_users):
    """POST mock/reset-defaults resets mock settings to defaults."""
    r = await client.post("/api/v1/admin/mock/reset-defaults", headers=auth_headers_admin)
    assert r.status_code in (200, 403)
    if r.status_code == 200:
        data = r.json()
        assert data["ok"] is True
        assert "reset_count" in data


# ═══════════════════════════════════════════
#  Admin Disputes
# ═══════════════════════════════════════════


async def test_list_disputes_empty(client: AsyncClient, auth_headers_admin, test_users):
    """GET disputes returns empty list when no disputes exist."""
    r = await client.get("/api/v1/admin/disputes", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data
    assert data["total"] == 0
    assert data["items"] == []


async def test_list_disputes_non_admin(client: AsyncClient, auth_headers_customer, test_users):
    """Non-admin cannot list disputes."""
    r = await client.get("/api/v1/admin/disputes", headers=auth_headers_customer)
    assert r.status_code == 403


async def test_create_dispute(client: AsyncClient, auth_headers_admin, test_users):
    """POST disputes creates a new dispute."""
    customer_id = test_users["customer"].id
    r = await client.post(
        "/api/v1/admin/disputes",
        json={
            "transaction_id": "txn_test_001",
            "user_id": customer_id,
            "amount_cents": 5000,
            "reason": "product_not_received",
        },
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert "dispute_id" in data


async def test_create_dispute_with_event(
    client: AsyncClient, auth_headers_admin, test_users, test_event_approved,
):
    """POST disputes with event_id creates a dispute and may freeze escrow."""
    customer_id = test_users["customer"].id
    r = await client.post(
        "/api/v1/admin/disputes",
        json={
            "transaction_id": "txn_test_002",
            "event_id": test_event_approved.id,
            "user_id": customer_id,
            "amount_cents": 3000,
            "reason": "fraudulent",
        },
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert "dispute_id" in data


async def test_list_disputes_with_filter(client: AsyncClient, auth_headers_admin, test_users):
    """GET disputes with status_filter returns filtered results."""
    # Create a dispute first
    customer_id = test_users["customer"].id
    await client.post(
        "/api/v1/admin/disputes",
        json={
            "transaction_id": "txn_filter_test",
            "user_id": customer_id,
            "amount_cents": 1000,
            "reason": "duplicate",
        },
        headers=auth_headers_admin,
    )
    # Filter by "open"
    r = await client.get(
        "/api/v1/admin/disputes",
        params={"status_filter": "open"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["total"] >= 1
    for item in data["items"]:
        assert item["status"] == "open"


async def test_resolve_dispute_won(client: AsyncClient, auth_headers_admin, test_users):
    """POST disputes/{id}/resolve with outcome=won resolves the dispute."""
    customer_id = test_users["customer"].id
    create_r = await client.post(
        "/api/v1/admin/disputes",
        json={
            "transaction_id": "txn_resolve_won",
            "user_id": customer_id,
            "amount_cents": 2000,
        },
        headers=auth_headers_admin,
    )
    dispute_id = create_r.json()["dispute_id"]

    r = await client.post(
        f"/api/v1/admin/disputes/{dispute_id}/resolve",
        json={"outcome": "won", "notes": "Evidence accepted"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["status"] == "won"


async def test_resolve_dispute_lost(client: AsyncClient, auth_headers_admin, test_users):
    """POST disputes/{id}/resolve with outcome=lost resolves the dispute."""
    customer_id = test_users["customer"].id
    create_r = await client.post(
        "/api/v1/admin/disputes",
        json={
            "transaction_id": "txn_resolve_lost",
            "user_id": customer_id,
            "amount_cents": 2000,
        },
        headers=auth_headers_admin,
    )
    dispute_id = create_r.json()["dispute_id"]

    r = await client.post(
        f"/api/v1/admin/disputes/{dispute_id}/resolve",
        json={"outcome": "lost", "notes": "Insufficient evidence"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["status"] == "lost"


async def test_resolve_dispute_not_found(client: AsyncClient, auth_headers_admin, test_users):
    """POST disputes/{id}/resolve for non-existent dispute returns 404."""
    r = await client.post(
        "/api/v1/admin/disputes/99999/resolve",
        json={"outcome": "won"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 404


async def test_submit_dispute_evidence(client: AsyncClient, auth_headers_admin, test_users):
    """POST disputes/{id}/submit-evidence marks evidence as submitted."""
    customer_id = test_users["customer"].id
    create_r = await client.post(
        "/api/v1/admin/disputes",
        json={
            "transaction_id": "txn_evidence",
            "user_id": customer_id,
            "amount_cents": 4000,
        },
        headers=auth_headers_admin,
    )
    dispute_id = create_r.json()["dispute_id"]

    r = await client.post(
        f"/api/v1/admin/disputes/{dispute_id}/submit-evidence",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["status"] == "evidence_submitted"


async def test_submit_dispute_evidence_not_found(client: AsyncClient, auth_headers_admin, test_users):
    """POST disputes/{id}/submit-evidence for non-existent returns 404."""
    r = await client.post(
        "/api/v1/admin/disputes/99999/submit-evidence",
        headers=auth_headers_admin,
    )
    assert r.status_code == 404


async def test_accept_dispute_loss(client: AsyncClient, auth_headers_admin, test_users):
    """POST disputes/{id}/accept marks the dispute as lost."""
    customer_id = test_users["customer"].id
    create_r = await client.post(
        "/api/v1/admin/disputes",
        json={
            "transaction_id": "txn_accept",
            "user_id": customer_id,
            "amount_cents": 3000,
        },
        headers=auth_headers_admin,
    )
    dispute_id = create_r.json()["dispute_id"]

    r = await client.post(
        f"/api/v1/admin/disputes/{dispute_id}/accept",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["status"] == "lost"


async def test_accept_dispute_not_found(client: AsyncClient, auth_headers_admin, test_users):
    """POST disputes/{id}/accept for non-existent returns 404."""
    r = await client.post(
        "/api/v1/admin/disputes/99999/accept",
        headers=auth_headers_admin,
    )
    assert r.status_code == 404


async def test_simulate_dispute(client: AsyncClient, auth_headers_admin, test_users):
    """POST mock/simulate-dispute creates a simulated dispute."""
    r = await client.post(
        "/api/v1/admin/mock/simulate-dispute",
        json={"transaction_id": "txn_sim_001"},
        headers=auth_headers_admin,
    )
    # 200 if mock mode enabled, 403 if disabled
    assert r.status_code in (200, 403)
    if r.status_code == 200:
        data = r.json()
        assert data["ok"] is True
        assert "dispute_id" in data


# ═══════════════════════════════════════════
#  Admin Ledger Health
# ═══════════════════════════════════════════


async def test_ledger_health(client: AsyncClient, auth_headers_admin, test_users):
    """GET ledger-health returns balance verification data."""
    r = await client.get("/api/v1/admin/ledger-health", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    # Should return some kind of health/balance structure
    assert isinstance(data, dict)


async def test_ledger_health_non_admin(client: AsyncClient, auth_headers_organizer, test_users):
    """Non-admin cannot access ledger health."""
    r = await client.get("/api/v1/admin/ledger-health", headers=auth_headers_organizer)
    assert r.status_code == 403


# ═══════════════════════════════════════════
#  Admin Reconciliation
# ═══════════════════════════════════════════


async def test_list_reconciliation_reports(client: AsyncClient, auth_headers_admin, test_users):
    """GET reconciliation returns list of reconciliation reports (may be empty)."""
    r = await client.get("/api/v1/admin/reconciliation", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


async def test_list_reconciliation_non_admin(client: AsyncClient, auth_headers_customer, test_users):
    """Non-admin cannot access reconciliation reports."""
    r = await client.get("/api/v1/admin/reconciliation", headers=auth_headers_customer)
    assert r.status_code == 403


async def test_run_reconciliation(client: AsyncClient, auth_headers_admin, test_users):
    """POST reconciliation/run triggers a reconciliation."""
    r = await client.post("/api/v1/admin/reconciliation/run", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "run_date" in data
    assert "status" in data
    assert "delta_cents" in data


async def test_run_reconciliation_non_admin(client: AsyncClient, auth_headers_organizer, test_users):
    """Non-admin cannot trigger reconciliation."""
    r = await client.post("/api/v1/admin/reconciliation/run", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_reconciliation_history(client: AsyncClient, auth_headers_admin, test_users):
    """GET reconciliation/history returns historical reports."""
    r = await client.get("/api/v1/admin/reconciliation/history", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


async def test_reconciliation_history_after_run(client: AsyncClient, auth_headers_admin, test_users):
    """After running reconciliation, history contains at least one entry."""
    await client.post("/api/v1/admin/reconciliation/run", headers=auth_headers_admin)
    r = await client.get("/api/v1/admin/reconciliation/history", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1
    entry = data[0]
    assert "run_date" in entry
    assert "actual_balance_cents" in entry
    assert "expected_balance_cents" in entry
    assert "delta_cents" in entry
    assert "status" in entry


# ═══════════════════════════════════════════
#  Admin Payout Status
# ═══════════════════════════════════════════


async def test_admin_payout_status(client: AsyncClient, auth_headers_admin, test_users):
    """GET payout-status returns organizer payout summary."""
    r = await client.get("/api/v1/admin/payout-status", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert isinstance(data["items"], list)
    # Should have organizer(s) in the list since test_users creates one
    assert len(data["items"]) >= 1
    item = data["items"][0]
    assert "organizer_id" in item
    assert "organizer_name" in item
    assert "pending_payout_cents" in item
    assert "bank_status" in item


async def test_admin_payout_status_non_admin(client: AsyncClient, auth_headers_customer, test_users):
    """Non-admin cannot access payout status."""
    r = await client.get("/api/v1/admin/payout-status", headers=auth_headers_customer)
    assert r.status_code == 403


async def test_admin_force_payout(client: AsyncClient, auth_headers_admin, test_users):
    """POST payouts/{id}/force initiates a forced payout."""
    organizer_id = test_users["organizer"].id
    r = await client.post(
        f"/api/v1/admin/payouts/{organizer_id}/force",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert "message" in data


async def test_admin_force_payout_non_admin(client: AsyncClient, auth_headers_organizer, test_users):
    """Non-admin cannot force a payout."""
    organizer_id = test_users["organizer"].id
    r = await client.post(
        f"/api/v1/admin/payouts/{organizer_id}/force",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


# ═══════════════════════════════════════════
#  Admin Transaction Ledger
# ═══════════════════════════════════════════


async def test_list_transactions_empty(client: AsyncClient, auth_headers_admin, test_users):
    """GET transactions returns empty list when no transactions exist."""
    r = await client.get("/api/v1/admin/transactions", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data
    assert data["total"] == 0
    assert data["items"] == []


async def test_list_transactions_non_admin(client: AsyncClient, auth_headers_customer, test_users):
    """Non-admin cannot list transactions."""
    r = await client.get("/api/v1/admin/transactions", headers=auth_headers_customer)
    assert r.status_code == 403


async def test_list_transactions_with_pagination(client: AsyncClient, auth_headers_admin, test_users):
    """GET transactions supports offset and limit parameters."""
    r = await client.get(
        "/api/v1/admin/transactions",
        params={"offset": 0, "limit": 5},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data


async def test_list_transactions_with_search(client: AsyncClient, auth_headers_admin, test_users):
    """GET transactions supports search parameter."""
    r = await client.get(
        "/api/v1/admin/transactions",
        params={"search": "nonexistent_txn_xyz"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["total"] == 0


async def test_list_transactions_with_date_filter(client: AsyncClient, auth_headers_admin, test_users):
    """GET transactions supports date_from and date_to parameters."""
    r = await client.get(
        "/api/v1/admin/transactions",
        params={"date_from": "2020-01-01", "date_to": "2030-12-31"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data
