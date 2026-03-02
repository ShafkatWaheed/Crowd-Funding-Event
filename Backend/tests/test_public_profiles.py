"""Public user profiles: public-profile, public-events, sponsor-public-profile."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# =====================================================================
# 1. Get public profile
# =====================================================================


async def test_public_profile(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """GET /users/{id}/public-profile returns a public profile for the organizer."""
    organizer = test_users["organizer"]
    r = await client.get(
        f"/api/v1/users/{organizer.id}/public-profile",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["id"] == organizer.id
    assert data["display_name"] == "Organizer"
    assert data["role"] == "organizer"
    # No email or phone should be exposed
    assert "email" not in data
    assert "phone" not in data
    # Must include event_metrics and trust
    assert "event_metrics" in data
    assert "trust" in data
    assert "sponsor_profile" in data


# =====================================================================
# 2. Get public events for a user
# =====================================================================


async def test_public_events(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """GET /users/{id}/public-events returns the organizer's public events."""
    organizer = test_users["organizer"]
    r = await client.get(
        f"/api/v1/users/{organizer.id}/public-events",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # The approved event should appear
    event_ids = [e["id"] for e in data]
    assert test_event_approved.id in event_ids


# =====================================================================
# 3. Public events pagination
# =====================================================================


async def test_public_events_pagination(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """GET /users/{id}/public-events with offset/limit returns paginated results."""
    organizer = test_users["organizer"]

    # With limit=1, should return at most 1 event
    r = await client.get(
        f"/api/v1/users/{organizer.id}/public-events",
        params={"offset": 0, "limit": 1},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) <= 1

    # With a large offset, should return empty list
    r2 = await client.get(
        f"/api/v1/users/{organizer.id}/public-events",
        params={"offset": 9999, "limit": 10},
        headers=auth_headers_customer,
    )
    assert r2.status_code == 200
    assert r2.json() == []


# =====================================================================
# 4. Public profile not found
# =====================================================================


async def test_public_profile_not_found(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """GET /users/999999/public-profile returns 404 for nonexistent user."""
    r = await client.get(
        "/api/v1/users/999999/public-profile",
        headers=auth_headers_customer,
    )
    assert r.status_code == 404


# =====================================================================
# 5. Sponsor public profile (returns data or 404 if no sponsor profile)
# =====================================================================


async def test_sponsor_public_profile(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """GET /users/{id}/sponsor-public-profile returns sponsor stats (0 bids for non-sponsor)."""
    organizer = test_users["organizer"]
    r = await client.get(
        f"/api/v1/users/{organizer.id}/sponsor-public-profile",
        headers=auth_headers_customer,
    )
    # Should return 200 even for a non-sponsor user (profile fields will be null)
    assert r.status_code == 200
    data = r.json()
    assert data["id"] == organizer.id
    assert data["display_name"] == "Organizer"
    assert data["total_bids"] == 0
    assert data["accepted_bids"] == 0
    assert data["events_sponsored"] == 0
    # Profile fields are null since the organizer has no SponsorProfile
    assert data["company_name"] is None


async def test_sponsor_public_profile_not_found(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """GET /users/999999/sponsor-public-profile returns 404 for nonexistent user."""
    r = await client.get(
        "/api/v1/users/999999/sponsor-public-profile",
        headers=auth_headers_customer,
    )
    assert r.status_code == 404
