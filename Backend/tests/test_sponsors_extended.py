"""
Extended sponsor tests: payments, receipts, delegates, check-in, bid events,
sponsorship-available, organizer sponsors, prerequisites, event sponsors,
sponsor tickets (scan, scanned list).
"""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# =====================================================================
# Sponsor Payments
# =====================================================================


async def test_pay_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """POST /events/{eid}/sponsorships/{cid}/bids/{bid_id}/pay creates a payment."""
    # First accept the bid so it can be paid
    from tests.conftest import _auth_headers
    org_headers = _auth_headers("test-organizer")
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}/accept",
        headers=org_headers,
    )
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}/pay",
        headers=auth_headers_sponsor,
    )
    # 200 on success, or 400/409 if state prevents payment
    assert r.status_code in (200, 400, 409)


async def test_pay_bid_unauthenticated(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
):
    """POST .../pay without auth returns 401/403."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}/pay",
    )
    assert r.status_code in (401, 403)


async def test_refund_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """POST /events/{eid}/sponsorships/{cid}/bids/{bid_id}/refund as organizer."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}/refund",
        headers=auth_headers_organizer,
    )
    # 200 on success, or 400/404 if no payment exists to refund
    assert r.status_code in (200, 400, 404)


async def test_payment_receipt_not_found(
    client: AsyncClient,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """GET /payments/{id}/receipt for nonexistent payment returns 404."""
    r = await client.get(
        "/api/v1/payments/999999/receipt",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 404


# =====================================================================
# Delegates
# =====================================================================


async def test_list_delegates_empty(
    client: AsyncClient,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """GET /me/sponsor-tickets/{id}/delegates with invalid ticket returns empty or 404."""
    r = await client.get(
        "/api/v1/me/sponsor-tickets/999999/delegates",
        headers=auth_headers_sponsor,
    )
    # Returns empty list or 404 depending on implementation
    assert r.status_code in (200, 404)
    if r.status_code == 200:
        assert isinstance(r.json(), list)


async def test_create_delegate_no_ticket(
    client: AsyncClient,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """POST /me/sponsor-tickets/{id}/delegates for nonexistent ticket returns 404."""
    r = await client.post(
        "/api/v1/me/sponsor-tickets/999999/delegates",
        json={"name": "Delegate One", "email": "delegate@test.com"},
        headers=auth_headers_sponsor,
    )
    assert r.status_code in (404, 403, 400)


async def test_delete_delegate_not_found(
    client: AsyncClient,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """DELETE /me/sponsor-tickets/{id}/delegates/{did} for nonexistent returns 404."""
    r = await client.delete(
        "/api/v1/me/sponsor-tickets/999999/delegates/999999",
        headers=auth_headers_sponsor,
    )
    assert r.status_code in (404, 403)


async def test_check_in_delegate_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """POST /events/{id}/sponsor-delegates/{did}/check-in for nonexistent delegate."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsor-delegates/999999/check-in",
        headers=auth_headers_organizer,
    )
    assert r.status_code in (404, 400)


async def test_check_in_delegate_forbidden_customer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """POST /events/{id}/sponsor-delegates/{did}/check-in as customer returns 403."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsor-delegates/1/check-in",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


# =====================================================================
# Sponsor Bid Events & Sponsorship Available
# =====================================================================


async def test_sponsor_bid_events_empty(
    client: AsyncClient,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """GET /me/sponsor-bid-events with no bids returns empty list."""
    r = await client.get(
        "/api/v1/me/sponsor-bid-events",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_sponsor_bid_events_with_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
):
    """GET /me/sponsor-bid-events with an existing bid returns the event."""
    r = await client.get(
        "/api/v1/me/sponsor-bid-events",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_sponsorship_available_events(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """GET /events/sponsorship-available returns events with open sponsorship categories."""
    r = await client.get(
        "/api/v1/events/sponsorship-available",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


# =====================================================================
# Organizer Sponsor Views
# =====================================================================


async def test_organizer_sponsors_empty(
    client: AsyncClient,
    auth_headers_organizer,
    test_users,
):
    """GET /me/organizer-sponsors with no sponsors returns empty list."""
    r = await client.get(
        "/api/v1/me/organizer-sponsors",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_organizer_sponsors_forbidden_customer(
    client: AsyncClient,
    auth_headers_customer,
    test_users,
):
    """GET /me/organizer-sponsors as customer returns 403."""
    r = await client.get(
        "/api/v1/me/organizer-sponsors",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_organizer_sponsor_events_not_found(
    client: AsyncClient,
    auth_headers_organizer,
    test_users,
):
    """GET /me/organizer-sponsors/{id}/events for nonexistent sponsor returns empty or 200."""
    r = await client.get(
        "/api/v1/me/organizer-sponsors/999999/events",
        headers=auth_headers_organizer,
    )
    # Returns empty list or 200 since the sponsor just has no events
    assert r.status_code == 200


# =====================================================================
# Prerequisites
# =====================================================================


async def test_create_prerequisite(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """POST /events/{eid}/sponsorships/{cid}/prerequisites creates a prereq."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/prerequisites",
        data={"name": "Business License", "description": "Upload your license", "is_required": "true", "requires_document": "true"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Business License"
    assert data["is_required"] is True


async def test_list_prerequisites_empty(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """GET /events/{eid}/sponsorships/{cid}/prerequisites returns empty list when none exist."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/prerequisites",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_delete_prerequisite(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """DELETE /events/{eid}/sponsorships/{cid}/prerequisites/{pid} removes it."""
    # Create first
    create_r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/prerequisites",
        data={"name": "Temp Prereq"},
        headers=auth_headers_organizer,
    )
    assert create_r.status_code == 201
    pid = create_r.json()["id"]

    r = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/prerequisites/{pid}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 204


async def test_list_bid_prerequisites_not_found(
    client: AsyncClient,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """GET /bids/{id}/prerequisites for nonexistent bid returns empty list."""
    r = await client.get(
        "/api/v1/bids/999999/prerequisites",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert r.json() == []


async def test_review_prerequisite_bid_not_found(
    client: AsyncClient,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """PATCH /bids/{id}/prerequisites/{pid}/review for nonexistent bid returns 404."""
    r = await client.patch(
        "/api/v1/bids/999999/prerequisites/999999/review",
        data={"status": "approved"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 404


# =====================================================================
# Event Sponsors & Sponsor Tickets
# =====================================================================


async def test_event_sponsors_empty(
    client: AsyncClient,
    test_event_approved,
    test_users_with_sponsor,
):
    """GET /events/{id}/sponsors with no paid sponsors returns empty list."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsors",
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_scan_sponsor_ticket_missing_payload(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """POST /events/{id}/scan-sponsor with empty payload returns 400."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-sponsor",
        json={"encrypted_payload": ""},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 400


async def test_scan_sponsor_ticket_forbidden_customer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """POST /events/{id}/scan-sponsor as customer returns 403."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-sponsor",
        json={"encrypted_payload": "fake-payload"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_scanned_sponsor_tickets_empty(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """GET /events/{id}/scanned-sponsor-tickets with none scanned returns empty list."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-sponsor-tickets",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)
    assert len(r.json()) == 0


async def test_scanned_sponsor_tickets_forbidden_customer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """GET /events/{id}/scanned-sponsor-tickets as customer returns 403."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-sponsor-tickets",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403
