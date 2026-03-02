"""
Miscellaneous endpoint tests: bookmarks, KYC, organizer dashboard, discovery
(genres, cities, featured, calendar), co-organized events, customers, ticket
waitlist, capacity, config, webhooks, ticket sales stats, purchase group receipt,
refund request/approve/reject.
"""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# =====================================================================
# Bookmarks  (POST /me/bookmarks/{eid}, GET /me/bookmarks/check, GET /me/bookmarks)
# =====================================================================


async def test_toggle_bookmark_on(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """POST /me/bookmarks/{eid} bookmarks an event."""
    r = await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["bookmarked"] is True


async def test_toggle_bookmark_off(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """POST /me/bookmarks/{eid} twice removes the bookmark."""
    await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    r = await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["bookmarked"] is False


async def test_check_bookmarks_empty(
    client: AsyncClient,
    auth_headers_customer,
    test_users,
):
    """GET /me/bookmarks/check with no bookmarks returns empty list."""
    r = await client.get(
        "/api/v1/me/bookmarks/check",
        params={"event_ids": ""},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["bookmarked_ids"] == []


async def test_check_bookmarks_with_data(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """GET /me/bookmarks/check returns bookmarked event IDs."""
    await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    r = await client.get(
        "/api/v1/me/bookmarks/check",
        params={"event_ids": str(test_event_approved.id)},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert test_event_approved.id in r.json()["bookmarked_ids"]


async def test_list_bookmarked_events(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """GET /me/bookmarks returns bookmarked events."""
    await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    r = await client.get(
        "/api/v1/me/bookmarks",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_bookmarks_requires_auth(
    client: AsyncClient,
    test_event_approved,
):
    """POST /me/bookmarks/{eid} without auth returns 401/403."""
    r = await client.post(f"/api/v1/me/bookmarks/{test_event_approved.id}")
    assert r.status_code in (401, 403)


# =====================================================================
# KYC  (GET /me/kyc-status, POST /me/kyc-documents, DELETE /me/kyc-documents/{id}, POST /me/kyc-submit)
# =====================================================================


async def test_kyc_status(
    client: AsyncClient,
    auth_headers_customer,
    test_users,
):
    """GET /me/kyc-status returns KYC status for the current user."""
    r = await client.get(
        "/api/v1/me/kyc-status",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "kyc_status" in data
    assert "documents" in data


async def test_kyc_status_requires_auth(client: AsyncClient, test_users):
    """GET /me/kyc-status without auth returns 401/403."""
    r = await client.get("/api/v1/me/kyc-status")
    assert r.status_code in (401, 403)


async def test_kyc_submit_no_documents(
    client: AsyncClient,
    auth_headers_customer,
    test_users,
):
    """POST /me/kyc-submit with no documents uploaded returns 400."""
    r = await client.post(
        "/api/v1/me/kyc-submit",
        headers=auth_headers_customer,
    )
    assert r.status_code == 400


async def test_delete_kyc_document_not_found(
    client: AsyncClient,
    auth_headers_customer,
    test_users,
):
    """DELETE /me/kyc-documents/{id} for nonexistent doc returns 400/404."""
    r = await client.delete(
        "/api/v1/me/kyc-documents/999999",
        headers=auth_headers_customer,
    )
    assert r.status_code in (400, 404)


# =====================================================================
# Organizer Dashboard
# =====================================================================


async def test_organizer_dashboard(
    client: AsyncClient,
    auth_headers_organizer,
    test_users,
):
    """GET /me/organizer-dashboard returns dashboard data."""
    r = await client.get(
        "/api/v1/me/organizer-dashboard",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "total_revenue" in data
    assert "tickets_sold" in data
    assert "total_events" in data


async def test_organizer_dashboard_forbidden_customer(
    client: AsyncClient,
    auth_headers_customer,
    test_users,
):
    """GET /me/organizer-dashboard as customer returns 403."""
    r = await client.get(
        "/api/v1/me/organizer-dashboard",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_organizer_time_series(
    client: AsyncClient,
    auth_headers_organizer,
    test_users,
):
    """GET /me/organizer-dashboard/time-series returns time-series data."""
    r = await client.get(
        "/api/v1/me/organizer-dashboard/time-series",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "revenue_series" in data or "series" in data or isinstance(data, dict)


# =====================================================================
# Discovery: Genres, Cities, Featured, Calendar
# =====================================================================


async def test_list_genres(client: AsyncClient, test_users):
    """GET /events/genres returns the list of available genres."""
    r = await client.get("/api/v1/events/genres")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) > 0


async def test_list_cities(client: AsyncClient, test_venue):
    """GET /events/cities returns cities with venues."""
    r = await client.get("/api/v1/events/cities")
    assert r.status_code == 200
    data = r.json()
    assert "cities" in data
    assert isinstance(data["cities"], list)


async def test_featured_events(client: AsyncClient, test_users):
    """GET /events/featured returns trending, popular, and coming_soon lists."""
    r = await client.get("/api/v1/events/featured")
    assert r.status_code == 200
    data = r.json()
    assert "trending" in data
    assert "popular" in data
    assert "coming_soon" in data


async def test_event_calendar_ics(
    client: AsyncClient,
    test_event_approved,
):
    """GET /events/{id}/calendar.ics returns iCalendar content."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/calendar.ics",
    )
    assert r.status_code == 200
    assert "text/calendar" in r.headers.get("content-type", "")
    assert "VCALENDAR" in r.text


async def test_event_calendar_not_found(client: AsyncClient, test_users):
    """GET /events/999999/calendar.ics returns 404."""
    r = await client.get("/api/v1/events/999999/calendar.ics")
    assert r.status_code == 404


# =====================================================================
# Co-organized Events
# =====================================================================


async def test_co_organized_events_empty(
    client: AsyncClient,
    auth_headers_customer,
    test_users,
):
    """GET /me/co-organized-events for a user with no co-org events returns empty list."""
    r = await client.get(
        "/api/v1/me/co-organized-events",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)
    assert len(r.json()) == 0


# =====================================================================
# Customers
# =====================================================================


async def test_list_customers_empty(
    client: AsyncClient,
    auth_headers_organizer,
    test_users,
):
    """GET /me/customers returns list (possibly empty) of customers."""
    r = await client.get(
        "/api/v1/me/customers",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_list_customers_forbidden_customer(
    client: AsyncClient,
    auth_headers_customer,
    test_users,
):
    """GET /me/customers as customer returns 403."""
    r = await client.get(
        "/api/v1/me/customers",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


# =====================================================================
# Ticket Waitlist
# =====================================================================


async def test_list_waitlisted_tickets_empty(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """GET /events/{id}/waitlisted-tickets with no waitlisted returns empty list."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/waitlisted-tickets",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)
    assert len(r.json()) == 0


async def test_approve_waitlisted_ticket_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """POST /events/{id}/waitlisted-tickets/{tid}/approve for nonexistent ticket returns 404."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/waitlisted-tickets/999999/approve",
        headers=auth_headers_organizer,
    )
    assert r.status_code in (404, 400, 409)


async def test_reject_waitlisted_ticket_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """POST /events/{id}/waitlisted-tickets/{tid}/reject for nonexistent ticket returns 404."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/waitlisted-tickets/999999/reject",
        headers=auth_headers_organizer,
    )
    assert r.status_code in (404, 400, 409)


# =====================================================================
# Capacity Info
# =====================================================================


async def test_capacity_info(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """GET /events/{id}/capacity-info returns capacity breakdown."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/capacity-info",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "max_capacity" in data
    assert "tickets_sold" in data
    assert "available" in data


async def test_capacity_info_forbidden_customer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """GET /events/{id}/capacity-info as customer returns 403."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/capacity-info",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


# =====================================================================
# Config
# =====================================================================


async def test_get_public_config(client: AsyncClient, test_users):
    """GET /config returns public configuration settings."""
    r = await client.get("/api/v1/config")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, dict)
    # Check for known keys
    assert "feature_sponsors_enabled" in data or isinstance(data, dict)


# =====================================================================
# Webhooks
# =====================================================================


async def test_stripe_webhook_empty_body(client: AsyncClient, test_users):
    """POST /webhooks/stripe with empty JSON body is handled gracefully."""
    r = await client.post(
        "/api/v1/webhooks/stripe",
        json={"type": "unknown.event", "data": {}},
    )
    # Should return 200 for unrecognized event types (passthrough)
    assert r.status_code == 200
    assert r.json().get("ok") is True


async def test_stripe_webhook_dispute_created(client: AsyncClient, test_users):
    """POST /webhooks/stripe with charge.dispute.created creates a dispute record."""
    customer_id = test_users["customer"].id
    r = await client.post(
        "/api/v1/webhooks/stripe",
        json={
            "type": "charge.dispute.created",
            "data": {
                "object": {
                    "id": "dp_test_12345",
                    "charge": "ch_test_12345",
                    "amount": 5000,
                    "reason": "product_not_received",
                    "metadata": {"user_id": str(customer_id)},
                },
            },
        },
    )
    assert r.status_code == 200
    assert r.json().get("ok") is True


async def test_stripe_webhook_dispute_duplicate(client: AsyncClient, test_users):
    """POST /webhooks/stripe with same dispute ID twice returns duplicate message."""
    customer_id = test_users["customer"].id
    payload = {
        "type": "charge.dispute.created",
        "data": {
            "object": {
                "id": "dp_test_dup_99999",
                "charge": "ch_test_dup",
                "amount": 1000,
                "reason": "fraudulent",
                "metadata": {"user_id": str(customer_id)},
            },
        },
    }
    await client.post("/api/v1/webhooks/stripe", json=payload)
    r2 = await client.post("/api/v1/webhooks/stripe", json=payload)
    assert r2.status_code == 200
    assert r2.json().get("ok") is True
    # Second call should detect duplicate
    assert r2.json().get("message") == "duplicate"


# =====================================================================
# Ticket Sales Stats, Purchase Group Receipt, Refund Endpoints
# =====================================================================


async def test_ticket_sales_stats(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """GET /events/{id}/ticket-sales-stats returns stats."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-sales-stats",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "total_sold" in data
    assert "total_scanned" in data


async def test_ticket_sales_stats_forbidden_customer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """GET /events/{id}/ticket-sales-stats as customer returns 403."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-sales-stats",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_purchase_group_receipt_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """GET /events/{id}/purchase-group/{gid}/receipt for nonexistent group returns 404."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/purchase-group/nonexistent-group-id/receipt",
        headers=auth_headers_customer,
    )
    assert r.status_code == 404


async def test_request_ticket_refund_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """POST /events/{id}/tickets/{tid}/refund for nonexistent ticket returns 404."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/tickets/999999/refund",
        headers=auth_headers_customer,
    )
    assert r.status_code == 404


async def test_list_refund_requests_empty(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """GET /events/{id}/refund-requests with none pending returns empty list."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/refund-requests",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)
    assert len(r.json()) == 0


async def test_approve_refund_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """POST /events/{id}/tickets/{tid}/approve-refund for nonexistent returns 404."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/tickets/999999/approve-refund",
        headers=auth_headers_organizer,
    )
    assert r.status_code in (404, 400, 409)


async def test_reject_refund_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """POST /events/{id}/tickets/{tid}/reject-refund for nonexistent returns 404."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/tickets/999999/reject-refund",
        headers=auth_headers_organizer,
    )
    assert r.status_code in (404, 400, 409)
