"""
Extended admin tests: escrow management, settings, KYC, user detail,
ticket/pledge lists, audit log, worker runs.
"""
import pytest
from unittest.mock import patch, AsyncMock


# ---------------------------------------------------------------------------
# Admin user management
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_users(client, db_session, test_users, auth_headers_admin):
    """Admin lists users."""
    resp = await client.get("/api/v1/admin/users", headers=auth_headers_admin)
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, (list, dict))


@pytest.mark.asyncio
async def test_admin_list_users_search(client, db_session, test_users, auth_headers_admin):
    """Admin searches users."""
    resp = await client.get(
        "/api/v1/admin/users",
        params={"search": "customer"},
        headers=auth_headers_admin,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_user_detail(client, db_session, test_users, auth_headers_admin):
    """Admin gets user detail."""
    customer = test_users["customer"]
    resp = await client.get(
        f"/api/v1/admin/users/{customer.id}/detail",
        headers=auth_headers_admin,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin event management
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_events(client, db_session, test_event_pending, auth_headers_admin):
    """Admin lists events."""
    resp = await client.get("/api/v1/admin/events", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_approve_event(client, db_session, test_event_pending, test_organizer_bank, auth_headers_admin):
    """Admin approves event."""
    resp = await client.post(
        f"/api/v1/admin/events/{test_event_pending.id}/approve",
        headers=auth_headers_admin,
        json={"approved": True},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_reject_event(client, db_session, test_event_pending, auth_headers_admin):
    """Admin rejects event."""
    resp = await client.post(
        f"/api/v1/admin/events/{test_event_pending.id}/approve",
        headers=auth_headers_admin,
        json={"approved": False},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_approve_not_admin(client, db_session, test_event_pending, auth_headers_customer):
    """Non-admin cannot approve events."""
    resp = await client.post(
        f"/api/v1/admin/events/{test_event_pending.id}/approve",
        headers=auth_headers_customer,
        json={"approved": True},
    )
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# Admin settings
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_settings(client, db_session, test_users, auth_headers_admin):
    """Admin lists platform settings."""
    resp = await client.get("/api/v1/admin/settings", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_update_setting(client, db_session, test_users, auth_headers_admin):
    """Admin updates a setting."""
    resp = await client.patch(
        "/api/v1/admin/settings/platform_name",
        headers=auth_headers_admin,
        json={"value": "Test Platform"},
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin tickets & pledges lists
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_tickets(client, db_session, test_ticket_sale, auth_headers_admin):
    """Admin lists all tickets."""
    resp = await client.get("/api/v1/admin/tickets", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_list_pledges(client, db_session, test_pledge, auth_headers_admin):
    """Admin lists all pledges."""
    resp = await client.get("/api/v1/admin/pledges", headers=auth_headers_admin)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin ticket escrows
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_ticket_escrows(client, db_session, test_users, auth_headers_admin):
    """Admin lists ticket escrows."""
    resp = await client.get("/api/v1/admin/ticket-escrows", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_list_sponsor_escrows(client, db_session, test_users, auth_headers_admin):
    """Admin lists sponsor escrows."""
    resp = await client.get("/api/v1/admin/sponsor-escrows", headers=auth_headers_admin)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin refund operations
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_refund_pledge(client, db_session, test_event_approved, test_pledge, auth_headers_admin):
    """Admin refunds a specific pledge."""
    resp = await client.post(
        f"/api/v1/admin/events/{test_event_approved.id}/pledges/{test_pledge.id}/refund",
        headers=auth_headers_admin,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin audit log & worker runs
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_audit_log(client, db_session, test_users, auth_headers_admin):
    """Admin gets audit log."""
    resp = await client.get("/api/v1/admin/audit-log", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_worker_runs(client, db_session, test_users, auth_headers_admin):
    """Admin gets worker runs."""
    resp = await client.get("/api/v1/admin/worker-runs", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_worker_summary(client, db_session, test_users, auth_headers_admin):
    """Admin gets worker summary."""
    resp = await client.get("/api/v1/admin/worker-summary", headers=auth_headers_admin)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin KYC
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_kyc_pending(client, db_session, test_users, auth_headers_admin):
    """Admin lists pending KYC users."""
    resp = await client.get("/api/v1/admin/kyc-pending", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_user_kyc_documents(client, db_session, test_users, auth_headers_admin):
    """Admin gets user KYC documents."""
    customer = test_users["customer"]
    resp = await client.get(
        f"/api/v1/admin/users/{customer.id}/kyc-documents",
        headers=auth_headers_admin,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin policy overrides
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_policy_overrides(client, db_session, test_event_approved, auth_headers_admin):
    """Admin sets policy overrides for event."""
    resp = await client.patch(
        f"/api/v1/admin/events/{test_event_approved.id}/policy-overrides",
        headers=auth_headers_admin,
        json={"waitlist_max_size": 100},
    )
    assert resp.status_code == 200
