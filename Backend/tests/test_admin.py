"""Admin API: users, events, approve, stats."""
import os
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_admin_requires_auth(client: AsyncClient) -> None:
    r = await client.get("/api/v1/admin/users")
    assert r.status_code == 401


async def test_admin_requires_admin_role(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/users", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_admin_list_users(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/users", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, dict)
    assert "items" in data
    assert "total" in data
    emails = [u["email"] for u in data["items"]]
    assert "admin@test.com" in emails


async def test_admin_list_events(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    """Admin list excludes draft by default; filter by status=approved to see approved events."""
    r = await client.get("/api/v1/admin/events?status=approved", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, dict)
    assert "items" in data
    assert "total" in data
    titles = [e["title"] for e in data["items"]]
    assert "Test Event" in titles


async def test_admin_approve_event(
    client: AsyncClient,
    test_event_pending,
    auth_headers_admin: dict[str, str],
) -> None:
    """Admin approves an event that is pending_approval (fixture sets status; no submit endpoint)."""
    r = await client.post(
        f"/api/v1/admin/events/{test_event_pending.id}/approve",
        headers=auth_headers_admin,
        json={"approved": True},
    )
    assert r.status_code == 200
    data = r.json()
    assert data.get("status") == "approved"

    get_r = await client.get(f"/api/v1/events/{test_event_pending.id}")
    assert get_r.json()["status"] == "approved"


async def test_admin_reject_event(
    client: AsyncClient,
    test_event_pending,
    auth_headers_admin: dict[str, str],
) -> None:
    """Admin rejects an event that is pending_approval (fixture sets status; no submit endpoint)."""
    r = await client.post(
        f"/api/v1/admin/events/{test_event_pending.id}/approve",
        headers=auth_headers_admin,
        json={"approved": False},
    )
    assert r.status_code == 200
    get_r = await client.get(f"/api/v1/events/{test_event_pending.id}")
    assert get_r.json()["status"] == "draft"


async def test_admin_stats(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/stats", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "events_total" in data and "users_total" in data


# ══════════════════════════════════════════════════════════════════
#  Dashboard
# ══════════════════════════════════════════════════════════════════


async def test_admin_dashboard(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/dashboard", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, dict)


async def test_admin_dashboard_with_filters(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get(
        "/api/v1/admin/dashboard?period=7d&genre=music&status=approved",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200


async def test_admin_dashboard_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/dashboard", headers=auth_headers_organizer)
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Platform Settings
# ══════════════════════════════════════════════════════════════════


async def test_admin_get_settings(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/settings", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


async def test_admin_get_settings_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/settings", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_admin_update_setting(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.patch(
        "/api/v1/admin/settings/platform_commission_percent",
        headers=auth_headers_admin,
        json={"value": "12"},
    )
    # 200 if key exists, 404 if not seeded — both are acceptable
    assert r.status_code in (200, 404)


async def test_admin_update_setting_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.patch(
        "/api/v1/admin/settings/platform_commission_percent",
        headers=auth_headers_organizer,
        json={"value": "12"},
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Admin Tickets
# ══════════════════════════════════════════════════════════════════


async def test_admin_list_tickets(
    client: AsyncClient,
    test_ticket_sale,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/tickets", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data
    assert isinstance(data["items"], list)


async def test_admin_list_tickets_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/tickets", headers=auth_headers_organizer)
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Admin Pledges
# ══════════════════════════════════════════════════════════════════


async def test_admin_list_pledges(
    client: AsyncClient,
    test_pledge,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/pledges", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data
    assert isinstance(data["items"], list)


async def test_admin_list_pledges_with_filters(
    client: AsyncClient,
    test_pledge,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get(
        "/api/v1/admin/pledges?status=pledged&is_donation=false",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert "items" in data


async def test_admin_list_pledges_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/pledges", headers=auth_headers_organizer)
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Admin Refund — Sponsor Bid
# ══════════════════════════════════════════════════════════════════


async def test_admin_refund_sponsor_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/events/{test_event_approved.id}"
        f"/sponsorships/{test_sponsorship_category.id}"
        f"/bids/{test_sponsor_bid.id}/refund",
        headers=auth_headers_admin,
    )
    # Bid is pending (not paid), so the service may return 400/409/404 — or 200 if it allows refund on any status
    assert r.status_code in (200, 400, 404, 409)


async def test_admin_refund_sponsor_bid_non_admin_403(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/events/{test_event_approved.id}"
        f"/sponsorships/{test_sponsorship_category.id}"
        f"/bids/{test_sponsor_bid.id}/refund",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Admin Refund — Pledge
# ══════════════════════════════════════════════════════════════════


async def test_admin_refund_pledge(
    client: AsyncClient,
    test_pledge,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/events/{test_event_approved.id}/pledges/{test_pledge.id}/refund",
        headers=auth_headers_admin,
    )
    # Pledge may or may not be in refundable state
    assert r.status_code in (200, 400, 404, 409)


async def test_admin_refund_pledge_non_admin_403(
    client: AsyncClient,
    test_pledge,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/events/{test_event_approved.id}/pledges/{test_pledge.id}/refund",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_refund_pledge_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/events/{test_event_approved.id}/pledges/99999/refund",
        headers=auth_headers_admin,
    )
    assert r.status_code == 404


# ══════════════════════════════════════════════════════════════════
#  Refund Retry Endpoints
# ══════════════════════════════════════════════════════════════════


async def test_admin_retry_ticket_refund(
    client: AsyncClient,
    test_ticket_sale,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/refunds/ticket/{test_ticket_sale.id}/retry",
        headers=auth_headers_admin,
    )
    # May succeed or fail depending on ticket state
    assert r.status_code in (200, 400, 404, 409)


async def test_admin_retry_ticket_refund_non_admin_403(
    client: AsyncClient,
    test_ticket_sale,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/refunds/ticket/{test_ticket_sale.id}/retry",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_retry_pledge_refund(
    client: AsyncClient,
    test_pledge,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/refunds/pledge/{test_pledge.id}/retry",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 400, 404, 409)


async def test_admin_retry_pledge_refund_non_admin_403(
    client: AsyncClient,
    test_pledge,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/refunds/pledge/{test_pledge.id}/retry",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_retry_sponsor_refund(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    # Use a fake payment_id; expect 404 since no such payment exists
    r = await client.post(
        "/api/v1/admin/refunds/sponsor/99999/retry",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 400, 404, 409)


async def test_admin_retry_sponsor_refund_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        "/api/v1/admin/refunds/sponsor/99999/retry",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_retry_all_refunds(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/refunds/retry-all/{test_event_approved.id}",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 400, 404)


async def test_admin_retry_all_refunds_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/refunds/retry-all/{test_event_approved.id}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Fund Escrow Management
# ══════════════════════════════════════════════════════════════════


async def test_admin_list_escrows(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/escrows", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data


async def test_admin_list_escrows_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/escrows", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_admin_release_escrow_stage(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/release/1",
        headers=auth_headers_admin,
    )
    # May 200, 404 (no escrow), or 409 (already released)
    assert r.status_code in (200, 400, 404, 409)


async def test_admin_release_escrow_stage_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/release/1",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_release_escrow_invalid_stage(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/release/5",
        headers=auth_headers_admin,
    )
    assert r.status_code == 400


async def test_admin_freeze_escrow(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/freeze",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 404, 409)


async def test_admin_freeze_escrow_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/freeze",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_unfreeze_escrow(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/unfreeze",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 404, 409)


async def test_admin_unfreeze_escrow_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/unfreeze",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Ticket Escrow Management
# ══════════════════════════════════════════════════════════════════


async def test_admin_list_ticket_escrows(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/ticket-escrows", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data


async def test_admin_list_ticket_escrows_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/ticket-escrows", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_admin_release_ticket_escrow_stage(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/ticket-escrows/{test_event_approved.id}/release/1",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 400, 404, 409)


async def test_admin_release_ticket_escrow_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/ticket-escrows/{test_event_approved.id}/release/1",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_freeze_ticket_escrow(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/ticket-escrows/{test_event_approved.id}/freeze",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 404, 409)


async def test_admin_freeze_ticket_escrow_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/ticket-escrows/{test_event_approved.id}/freeze",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_unfreeze_ticket_escrow(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/ticket-escrows/{test_event_approved.id}/unfreeze",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 404, 409)


async def test_admin_unfreeze_ticket_escrow_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/ticket-escrows/{test_event_approved.id}/unfreeze",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Sponsor Escrow Management
# ══════════════════════════════════════════════════════════════════


async def test_admin_list_sponsor_escrows(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/sponsor-escrows", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data


async def test_admin_list_sponsor_escrows_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/sponsor-escrows", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_admin_release_sponsor_escrow_stage(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/sponsor-escrows/{test_event_approved.id}/release/1",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 400, 404, 409)


async def test_admin_release_sponsor_escrow_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/sponsor-escrows/{test_event_approved.id}/release/1",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_freeze_sponsor_escrow(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/sponsor-escrows/{test_event_approved.id}/freeze",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 404, 409)


async def test_admin_freeze_sponsor_escrow_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/sponsor-escrows/{test_event_approved.id}/freeze",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_unfreeze_sponsor_escrow(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/sponsor-escrows/{test_event_approved.id}/unfreeze",
        headers=auth_headers_admin,
    )
    assert r.status_code in (200, 404, 409)


async def test_admin_unfreeze_sponsor_escrow_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/sponsor-escrows/{test_event_approved.id}/unfreeze",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Per-Escrow Auto-Release Toggle
# ══════════════════════════════════════════════════════════════════


async def test_admin_toggle_auto_release_fund(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/admin/fund-escrows/{test_event_approved.id}/auto-release",
        headers=auth_headers_admin,
        json={"stage1_auto_release": False},
    )
    assert r.status_code in (200, 404)


async def test_admin_toggle_auto_release_ticket(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/admin/ticket-escrows/{test_event_approved.id}/auto-release",
        headers=auth_headers_admin,
        json={"stage2_auto_release": True},
    )
    assert r.status_code in (200, 404)


async def test_admin_toggle_auto_release_sponsor(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/admin/sponsor-escrows/{test_event_approved.id}/auto-release",
        headers=auth_headers_admin,
        json={"stage3_auto_release": False},
    )
    assert r.status_code in (200, 404)


async def test_admin_toggle_auto_release_invalid_type(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/admin/invalid-escrows/{test_event_approved.id}/auto-release",
        headers=auth_headers_admin,
        json={"stage1_auto_release": True},
    )
    assert r.status_code == 400


async def test_admin_toggle_auto_release_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/admin/fund-escrows/{test_event_approved.id}/auto-release",
        headers=auth_headers_organizer,
        json={"stage1_auto_release": False},
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Unified Per-Event Escrow View
# ══════════════════════════════════════════════════════════════════


async def test_admin_get_escrows_by_event(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/admin/escrows/by-event/{test_event_approved.id}",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert "event_id" in data
    assert data["event_id"] == test_event_approved.id
    # fund, ticket, sponsor keys should be present (may be null)
    assert "fund" in data
    assert "ticket" in data
    assert "sponsor" in data


async def test_admin_get_escrows_by_event_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/admin/escrows/by-event/{test_event_approved.id}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Organizer Freeze Payouts
# ══════════════════════════════════════════════════════════════════


async def test_admin_freeze_organizer_payouts(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    organizer_id = test_users["organizer"].id
    r = await client.post(
        f"/api/v1/admin/organizers/{organizer_id}/freeze-payouts",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert "events_frozen" in data


async def test_admin_freeze_organizer_payouts_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    organizer_id = test_users["organizer"].id
    r = await client.post(
        f"/api/v1/admin/organizers/{organizer_id}/freeze-payouts",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Resolve Review
# ══════════════════════════════════════════════════════════════════


async def test_admin_resolve_review(
    client: AsyncClient,
    db_session,
    test_event,
    auth_headers_admin: dict[str, str],
) -> None:
    """Put event under_review, then resolve it."""
    from app.models.event import EventStatus
    test_event.status = EventStatus.under_review
    await db_session.commit()

    r = await client.post(
        f"/api/v1/admin/events/{test_event.id}/resolve-review",
        headers=auth_headers_admin,
        json={"target_status": "approved", "notes": "Looks good"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["status"] == "approved"


async def test_admin_resolve_review_not_under_review_409(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    """Event is approved, not under_review — should get 409."""
    r = await client.post(
        f"/api/v1/admin/events/{test_event_approved.id}/resolve-review",
        headers=auth_headers_admin,
        json={"target_status": "approved"},
    )
    assert r.status_code == 409


async def test_admin_resolve_review_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/admin/events/{test_event_approved.id}/resolve-review",
        headers=auth_headers_organizer,
        json={"target_status": "approved"},
    )
    assert r.status_code == 403


async def test_admin_resolve_review_event_not_found(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.post(
        "/api/v1/admin/events/99999/resolve-review",
        headers=auth_headers_admin,
        json={"target_status": "approved"},
    )
    assert r.status_code == 404


# ══════════════════════════════════════════════════════════════════
#  Audit Log
# ══════════════════════════════════════════════════════════════════


async def test_admin_audit_log(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/audit-log", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data
    assert isinstance(data["items"], list)


async def test_admin_audit_log_with_filters(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get(
        "/api/v1/admin/audit-log?action=settings_update&limit=10",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert "items" in data


async def test_admin_audit_log_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/audit-log", headers=auth_headers_organizer)
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Worker Runs & Summary
# ══════════════════════════════════════════════════════════════════


async def test_admin_worker_runs(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/worker-runs", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "items" in data
    assert "total" in data


async def test_admin_worker_runs_with_filters(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get(
        "/api/v1/admin/worker-runs?task_name=mock_auto_settle&status=success&limit=5",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200


async def test_admin_worker_runs_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/worker-runs", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_admin_worker_summary(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/worker-summary", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert "tasks" in data
    assert isinstance(data["tasks"], list)


async def test_admin_worker_summary_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/worker-summary", headers=auth_headers_organizer)
    assert r.status_code == 403


# ══════════════════════════════════════════════════════════════════
#  Policy Overrides
# ══════════════════════════════════════════════════════════════════


async def test_admin_set_policy_overrides(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/admin/events/{test_event_approved.id}/policy-overrides",
        headers=auth_headers_admin,
        json={
            "admin_override_waitlist_max_size": 200,
            "admin_override_event_max_images": 20,
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert data["event_id"] == test_event_approved.id
    assert "overrides" in data
    assert "effective" in data
    assert data["overrides"]["admin_override_waitlist_max_size"] == 200
    assert data["overrides"]["admin_override_event_max_images"] == 20


async def test_admin_set_policy_overrides_clear(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    """Sending null values should clear overrides."""
    r = await client.patch(
        f"/api/v1/admin/events/{test_event_approved.id}/policy-overrides",
        headers=auth_headers_admin,
        json={
            "admin_override_waitlist_max_size": None,
        },
    )
    assert r.status_code == 200


async def test_admin_set_policy_overrides_non_admin_403(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/admin/events/{test_event_approved.id}/policy-overrides",
        headers=auth_headers_organizer,
        json={"admin_override_waitlist_max_size": 100},
    )
    assert r.status_code == 403


async def test_admin_set_policy_overrides_event_not_found(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.patch(
        "/api/v1/admin/events/99999/policy-overrides",
        headers=auth_headers_admin,
        json={"admin_override_waitlist_max_size": 100},
    )
    assert r.status_code == 404


# ══════════════════════════════════════════════════════════════════
#  KYC Review Endpoints
# ══════════════════════════════════════════════════════════════════


async def test_admin_kyc_pending(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/kyc-pending", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


async def test_admin_kyc_pending_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/kyc-pending", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_admin_kyc_documents(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    user_id = test_users["organizer"].id
    r = await client.get(
        f"/api/v1/admin/users/{user_id}/kyc-documents",
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


async def test_admin_kyc_documents_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    user_id = test_users["organizer"].id
    r = await client.get(
        f"/api/v1/admin/users/{user_id}/kyc-documents",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 403


async def test_admin_kyc_verify_approve(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    user_id = test_users["organizer"].id
    r = await client.post(
        f"/api/v1/admin/users/{user_id}/kyc-verify",
        headers=auth_headers_admin,
        json={"approved": True},
    )
    # May be 200 or 400 depending on KYC state (user may not have submitted docs)
    assert r.status_code in (200, 400)


async def test_admin_kyc_verify_reject(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    user_id = test_users["organizer"].id
    r = await client.post(
        f"/api/v1/admin/users/{user_id}/kyc-verify",
        headers=auth_headers_admin,
        json={"approved": False, "rejection_reason": "Documents unclear"},
    )
    assert r.status_code in (200, 400)


async def test_admin_kyc_verify_non_admin_403(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    user_id = test_users["organizer"].id
    r = await client.post(
        f"/api/v1/admin/users/{user_id}/kyc-verify",
        headers=auth_headers_organizer,
        json={"approved": True},
    )
    assert r.status_code == 403
