"""
Extended funding tests: refund flows, admin list, reservations, receipts.
"""
import pytest
from unittest.mock import patch, AsyncMock

from app.models.funding import Funding, FundingStatus


# ---------------------------------------------------------------------------
# Pledge refund flows
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_unpledge_returns_refund_info(client, db_session, test_event_approved, test_pledge, test_registration, auth_headers_customer):
    """Unpledge returns refund info with amount."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/unpledge",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "refunded_cents" in data


@pytest.mark.asyncio
async def test_unpledge_no_pledge(client, db_session, test_event_approved, test_registration, auth_headers_customer):
    """Unpledge with no existing pledge."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/unpledge",
        headers=auth_headers_customer,
    )
    # Should succeed (no pledges to refund) or return appropriate error
    assert resp.status_code in (200, 404, 409)


# ---------------------------------------------------------------------------
# Funding details & escrow endpoint
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_funding_details(client, db_session, test_event_approved, test_pledge, auth_headers_customer):
    """GET funding details for event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/funding",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_escrow_endpoint(client, db_session, test_event_approved, auth_headers_organizer):
    """GET escrow status for event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/escrow",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Pledge receipt
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_pledge_receipt(client, db_session, test_event_approved, test_pledge, auth_headers_customer):
    """Customer gets pledge receipt."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/pledges/{test_pledge.id}/receipt",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_pledge_receipt_via_me(client, db_session, test_pledge, auth_headers_customer):
    """Customer gets pledge receipt via /me/ endpoint."""
    resp = await client.get(
        f"/api/v1/me/pledges/{test_pledge.id}/receipt",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Organizer pledge listing
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_organizer_pledges_list(client, db_session, test_event_approved, test_pledge, auth_headers_organizer):
    """Organizer lists pledges for their events."""
    resp = await client.get("/api/v1/me/organizer-pledges", headers=auth_headers_organizer)
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


# ---------------------------------------------------------------------------
# Pledge preview
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_pledge_preview(client, db_session, test_event_approved, test_registration, auth_headers_customer):
    """Pledge preview returns breakdown."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/pledge-preview",
        params={"amount_cents": 5000, "reserved_spots": 1},
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "amount_cents" in data or "total_cents" in data or "platform_cut_cents" in data


# ---------------------------------------------------------------------------
# Refund status
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_refund_status(client, db_session, test_event_approved, auth_headers_customer):
    """GET refund status for event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/refund-status",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Customer pledge list with sort
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_my_pledges_sort(client, db_session, test_pledge, auth_headers_customer):
    """Customer lists pledges with different sort orders."""
    for sort in ["newest", "oldest"]:
        resp = await client.get(
            "/api/v1/me/pledges",
            params={"sort_by": sort},
            headers=auth_headers_customer,
        )
        assert resp.status_code == 200
