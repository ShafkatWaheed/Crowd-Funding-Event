"""Funding API: pledge-preview, pledge, unpledge, receipt, refund-status, funding summary, escrow, my-pledges."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ----- Pledge preview -----

async def test_pledge_preview(client: AsyncClient, test_event_approved, auth_headers_customer, test_users):
    """GET pledge preview returns amount breakdown."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/pledge-preview",
        params={"amount_cents": 1000},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "amount_cents" in data


async def test_pledge_preview_unauthenticated(client: AsyncClient, test_event_approved):
    """Pledge preview without auth returns 401/403."""
    r = await client.get(f"/api/v1/events/{test_event_approved.id}/pledge-preview")
    assert r.status_code in (401, 403)


# ----- Create pledge -----

async def test_create_pledge(client: AsyncClient, test_event_approved, auth_headers_customer, test_users):
    """POST pledge on approved event succeeds."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/pledge",
        json={"amount_cents": 1000, "reserved_spots": 0},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["amount_cents"] == 1000
    assert data["status"] == "pledged"


async def test_create_pledge_not_approved_event(client: AsyncClient, test_event, auth_headers_customer, test_users):
    """POST pledge on draft event fails with 409."""
    r = await client.post(
        f"/api/v1/events/{test_event.id}/pledge",
        json={"amount_cents": 1000, "reserved_spots": 0},
        headers=auth_headers_customer,
    )
    assert r.status_code == 409


async def test_create_pledge_duplicate(
    client: AsyncClient, test_event_approved, test_pledge, auth_headers_customer, test_users
):
    """Second pledge by same user on same event succeeds (multiple pledges allowed)."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/pledge",
        json={"amount_cents": 500, "reserved_spots": 0},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["amount_cents"] == 500
    assert data["status"] == "pledged"


# ----- Unpledge -----

async def test_unpledge(client: AsyncClient, test_event_approved, test_pledge, auth_headers_customer, test_users):
    """POST unpledge returns refund info."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/unpledge",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "refunded_cents" in data


async def test_unpledge_no_pledge(client: AsyncClient, test_event_approved, auth_headers_customer, test_users):
    """Unpledge without existing pledge returns 200 with 0 refund (no-op)."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/unpledge",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["refunded_cents"] == 0


# ----- Funding summary (public) -----

async def test_funding_summary(client: AsyncClient, test_event_approved, test_users):
    """GET funding summary is public, returns summary data."""
    r = await client.get(f"/api/v1/events/{test_event_approved.id}/funding")
    assert r.status_code == 200
    data = r.json()
    assert "total_pledged_cents" in data
    assert "goal_cents" in data


async def test_funding_summary_with_pledge(client: AsyncClient, test_event_approved, test_pledge, test_users):
    """Funding summary reflects existing pledge."""
    r = await client.get(f"/api/v1/events/{test_event_approved.id}/funding")
    assert r.status_code == 200
    data = r.json()
    assert data["total_pledged_cents"] >= test_pledge.amount_cents


# ----- Pledge receipt -----

async def test_pledge_receipt(
    client: AsyncClient, test_event_approved, test_pledge, auth_headers_customer, test_users
):
    """GET receipt for own pledge returns receipt data."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/pledges/{test_pledge.id}/receipt",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["receipt_number"] == "PLG-TEST-001"


async def test_pledge_receipt_wrong_user(
    client: AsyncClient, test_event_approved, test_pledge, auth_headers_organizer2, test_users
):
    """GET receipt as non-owner/non-organizer returns 403."""
    # organizer2 is not the event organizer and not the pledger
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/pledges/{test_pledge.id}/receipt",
        headers=auth_headers_organizer2,
    )
    assert r.status_code == 403


async def test_pledge_receipt_organizer(
    client: AsyncClient, test_event_approved, test_pledge, auth_headers_organizer, test_users
):
    """Event organizer can view pledge receipt."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/pledges/{test_pledge.id}/receipt",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200


# ----- My pledge receipt (user routes) -----

async def test_my_pledge_receipt(
    client: AsyncClient, test_event_approved, test_pledge, auth_headers_customer, test_users
):
    """GET /me/pledges/{id}/receipt returns receipt."""
    r = await client.get(
        f"/api/v1/me/pledges/{test_pledge.id}/receipt",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["receipt_number"] == "PLG-TEST-001"


# ----- List my pledges -----

async def test_list_my_pledges(
    client: AsyncClient, test_event_approved, test_pledge, auth_headers_customer, test_users
):
    """GET /me/pledges returns pledges list."""
    r = await client.get("/api/v1/me/pledges", headers=auth_headers_customer)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_list_my_pledges_pagination(
    client: AsyncClient, test_event_approved, test_pledge, auth_headers_customer, test_users
):
    """Pagination params work."""
    r = await client.get(
        "/api/v1/me/pledges",
        params={"offset": 0, "limit": 5},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200


# ----- Organizer pledges -----

async def test_organizer_pledges(
    client: AsyncClient, test_event_approved, test_pledge, auth_headers_organizer, test_users
):
    """GET /me/organizer-pledges returns pledges on organizer's events."""
    r = await client.get("/api/v1/me/organizer-pledges", headers=auth_headers_organizer)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


# ----- Refund status -----

async def test_refund_status(client: AsyncClient, test_event_approved, auth_headers_customer, test_users):
    """GET refund-status returns status counts."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/refund-status",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] in ("none", "processing", "completed", "failed")


# ----- Escrow summary (public) -----

async def test_escrow_summary(client: AsyncClient, test_event_approved, test_users):
    """GET escrow returns summary (public)."""
    r = await client.get(f"/api/v1/events/{test_event_approved.id}/escrow")
    assert r.status_code == 200
