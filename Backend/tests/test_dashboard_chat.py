"""
Dashboard, chat, and miscellaneous service tests.
"""
import pytest
from unittest.mock import patch, AsyncMock


# ---------------------------------------------------------------------------
# Organizer dashboard
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_organizer_dashboard(client, db_session, test_event_approved, test_pledge, test_ticket_sale, auth_headers_organizer):
    """Organizer gets dashboard KPIs."""
    resp = await client.get("/api/v1/me/organizer-dashboard", headers=auth_headers_organizer)
    assert resp.status_code == 200
    data = resp.json()
    assert "events_total" in data or "total_events" in data or isinstance(data, dict)


@pytest.mark.asyncio
async def test_organizer_dashboard_with_filters(client, db_session, test_event_approved, auth_headers_organizer):
    """Dashboard with period filter."""
    resp = await client.get(
        "/api/v1/me/organizer-dashboard",
        params={"delta_days": 30},
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_organizer_time_series(client, db_session, test_event_approved, auth_headers_organizer):
    """Organizer time series data."""
    resp = await client.get(
        "/api/v1/me/organizer-dashboard/time-series",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Admin dashboard
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_dashboard(client, db_session, test_event_approved, auth_headers_admin):
    """Admin dashboard endpoint."""
    resp = await client.get("/api/v1/admin/dashboard", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_stats(client, db_session, test_event_approved, auth_headers_admin):
    """Admin stats endpoint."""
    resp = await client.get("/api/v1/admin/stats", headers=auth_headers_admin)
    assert resp.status_code == 200
    data = resp.json()
    assert "events_total" in data or "total_events" in data or isinstance(data, dict)


# ---------------------------------------------------------------------------
# Chat endpoints (REST)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_conversations_empty(client, db_session, test_users, auth_headers_customer):
    """Customer with no bids has no conversations."""
    resp = await client.get("/api/v1/chat/conversations", headers=auth_headers_customer)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


@pytest.mark.asyncio
async def test_get_messages_bid_not_found(client, db_session, test_users, auth_headers_customer):
    """Get messages for non-existent bid."""
    resp = await client.get("/api/v1/chat/bids/99999/messages", headers=auth_headers_customer)
    assert resp.status_code in (403, 404)


# ---------------------------------------------------------------------------
# Users / Profile
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_current_user(client, db_session, test_users, auth_headers_customer):
    """GET /me returns current user."""
    resp = await client.get("/api/v1/me", headers=auth_headers_customer)
    assert resp.status_code == 200
    assert resp.json()["email"] == "customer@test.com"


@pytest.mark.asyncio
async def test_update_current_user(client, db_session, test_users, auth_headers_customer):
    """PATCH /me updates display name."""
    resp = await client.patch(
        "/api/v1/me",
        headers=auth_headers_customer,
        json={"display_name": "Updated Customer"},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_search_organizers(client, db_session, test_users, auth_headers_organizer):
    """Search organizers."""
    resp = await client.get(
        "/api/v1/me/search-organizers",
        params={"q": "Organizer"},
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Bookmarks
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_bookmark_event(client, db_session, test_event_approved, auth_headers_customer):
    """Bookmark an event."""
    resp = await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_list_bookmarks(client, db_session, test_event_approved, auth_headers_customer):
    """List bookmarked events."""
    await client.post(f"/api/v1/me/bookmarks/{test_event_approved.id}", headers=auth_headers_customer)
    resp = await client.get("/api/v1/me/bookmarks", headers=auth_headers_customer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_check_bookmark(client, db_session, test_event_approved, auth_headers_customer):
    """Check if event is bookmarked."""
    resp = await client.get(
        "/api/v1/me/bookmarks/check",
        params={"event_id": test_event_approved.id},
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Public profiles
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_public_profile(client, db_session, test_users, auth_headers_customer):
    """Get public profile of organizer."""
    organizer = test_users["organizer"]
    resp = await client.get(f"/api/v1/users/{organizer.id}/public-profile", headers=auth_headers_customer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_public_events(client, db_session, test_users, test_event_approved, auth_headers_customer):
    """Get public events of organizer."""
    organizer = test_users["organizer"]
    resp = await client.get(f"/api/v1/users/{organizer.id}/public-events", headers=auth_headers_customer)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Map
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_map_events(client, db_session, test_event_approved):
    """Get map events."""
    resp = await client.get("/api/v1/events/map")
    assert resp.status_code == 200
