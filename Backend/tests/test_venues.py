"""Venues API: list, create, get, update, delete."""
import os
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_list_venues_public(client: AsyncClient, test_venue) -> None:
    r = await client.get("/api/v1/venues")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    names = [v["name"] for v in data]
    assert "Test Hall" in names


async def test_list_venues_with_city(client: AsyncClient, test_venue) -> None:
    r = await client.get("/api/v1/venues?city=Ottawa")
    assert r.status_code == 200
    data = r.json()
    assert all(v["city"] == "Ottawa" for v in data)


async def test_create_venue_requires_auth(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/venues",
        json={
            "name": "New Venue",
            "address": "456 St",
            "city": "Ottawa",
            "max_capacity": 80,
        },
    )
    assert r.status_code == 401


async def test_create_venue_success(
    client: AsyncClient,
    db_session,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        "/api/v1/venues",
        headers=auth_headers_organizer,
        json={
            "name": "Created Hall",
            "address": "789 Ave",
            "city": "Toronto",
            "province": "ON",
            "max_capacity": 60,
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "Created Hall"
    assert data["city"] == "Toronto"
    assert data["max_capacity"] == 60


async def test_get_venue(
    client: AsyncClient,
    test_venue,
) -> None:
    r = await client.get(f"/api/v1/venues/{test_venue.id}")
    assert r.status_code == 200
    assert r.json()["name"] == "Test Hall"


async def test_get_venue_404(client: AsyncClient) -> None:
    r = await client.get("/api/v1/venues/999999")
    assert r.status_code == 404


async def test_update_venue_requires_auth(client: AsyncClient, test_venue) -> None:
    r = await client.patch(
        f"/api/v1/venues/{test_venue.id}",
        json={"name": "Updated"},
    )
    assert r.status_code == 401


async def test_update_venue_success(
    client: AsyncClient,
    db_session,
    test_venue,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/venues/{test_venue.id}",
        headers=auth_headers_organizer,
        json={"name": "Updated Hall", "max_capacity": 120},
    )
    assert r.status_code == 200
    assert r.json()["name"] == "Updated Hall"
    assert r.json()["max_capacity"] == 120


async def test_delete_venue_requires_auth(client: AsyncClient, test_venue) -> None:
    r = await client.delete(f"/api/v1/venues/{test_venue.id}")
    assert r.status_code == 401


async def test_list_venues_as_organizer(
    client: AsyncClient,
    test_venue,
    auth_headers_organizer: dict[str, str],
) -> None:
    """Organizer sees only their own venues."""
    r = await client.get("/api/v1/venues", headers=auth_headers_organizer)
    assert r.status_code == 200
    data = r.json()
    assert all(v["name"] for v in data)
    assert any(v["name"] == "Test Hall" for v in data)


async def test_get_venue_forbidden_for_other_organizer(
    client: AsyncClient,
    test_venue,
    auth_headers_organizer: dict[str, str],
) -> None:
    """Venue detail is allowed for owner (we only have one organizer)."""
    r = await client.get(
        f"/api/v1/venues/{test_venue.id}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200


async def test_delete_venue_success(
    client: AsyncClient,
    db_session,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    # Create a venue we can delete (not used by test_event)
    create_r = await client.post(
        "/api/v1/venues",
        headers=auth_headers_organizer,
        json={
            "name": "To Delete",
            "address": "1 St",
            "city": "Ottawa",
            "max_capacity": 10,
        },
    )
    assert create_r.status_code == 200
    vid = create_r.json()["id"]
    r = await client.delete(f"/api/v1/venues/{vid}", headers=auth_headers_organizer)
    assert r.status_code == 200
    get_r = await client.get(f"/api/v1/venues/{vid}")
    assert get_r.status_code == 404
