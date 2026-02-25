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
    test_event_approved,
    auth_headers_admin: dict[str, str],
) -> None:
    """Admin list excludes draft by default; filter by status=approved to see approved events."""
    r = await client.get("/api/v1/admin/events?status=approved", headers=auth_headers_admin)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    titles = [e["title"] for e in data]
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
