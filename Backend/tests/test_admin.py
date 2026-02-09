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
    assert isinstance(data, list)
    emails = [u["email"] for u in data]
    assert "admin@test.com" in emails


async def test_admin_list_events(
    client: AsyncClient,
    test_event,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/admin/events", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    titles = [e["title"] for e in data]
    assert "Test Event" in titles


async def test_admin_approve_event(
    client: AsyncClient,
    test_event,
    auth_headers_organizer: dict[str, str],
    auth_headers_admin: dict[str, str],
) -> None:
    # First submit for approval
    await client.post(
        f"/api/v1/events/{test_event.id}/submit",
        headers=auth_headers_organizer,
    )
    r = await client.post(
        f"/api/v1/admin/events/{test_event.id}/approve",
        headers=auth_headers_admin,
        json={"approved": True},
    )
    assert r.status_code == 200
    data = r.json()
    assert data.get("status") == "approved"

    get_r = await client.get(f"/api/v1/events/{test_event.id}")
    assert get_r.json()["status"] == "approved"


async def test_admin_reject_event(
    client: AsyncClient,
    auth_headers_organizer: dict[str, str],
    auth_headers_admin: dict[str, str],
    test_venue,
) -> None:
    create_r = await client.post(
        "/api/v1/events",
        headers=auth_headers_organizer,
        json={
            "venue_id": test_venue.id,
            "title": "To Reject",
            "start_time": "2030-01-15T18:00:00Z",
            "end_time": "2030-01-15T20:00:00Z",
            "min_pledge_cents": 100,
            "max_capacity": 10,
        },
    )
    assert create_r.status_code == 200
    eid = create_r.json()["id"]
    await client.post(f"/api/v1/events/{eid}/submit", headers=auth_headers_organizer)
    r = await client.post(
        f"/api/v1/admin/events/{eid}/approve",
        headers=auth_headers_admin,
        json={"approved": False},
    )
    assert r.status_code == 200
    get_r = await client.get(f"/api/v1/events/{eid}")
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
