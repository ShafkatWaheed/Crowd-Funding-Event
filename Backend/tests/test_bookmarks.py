"""
Bookmark API tests: toggle, check, list bookmarked events.
"""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_toggle_bookmark_add(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """POST /me/bookmarks/{event_id} creates a bookmark, returns bookmarked=True."""
    r = await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["bookmarked"] is True


async def test_toggle_bookmark_remove(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """POST /me/bookmarks/{event_id} twice removes the bookmark."""
    # Add
    await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    # Remove
    r = await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["bookmarked"] is False


async def test_check_bookmarks(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """GET /me/bookmarks/check?event_ids=... returns bookmarked IDs."""
    # Bookmark the event first
    await client.post(
        f"/api/v1/me/bookmarks/{test_event_approved.id}",
        headers=auth_headers_customer,
    )
    r = await client.get(
        f"/api/v1/me/bookmarks/check?event_ids={test_event_approved.id},99999",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert test_event_approved.id in data["bookmarked_ids"]
    assert 99999 not in data["bookmarked_ids"]


async def test_list_bookmarked_events(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """GET /me/bookmarks returns bookmarked events with eager loads."""
    # Bookmark the event first
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
    assert any(e["id"] == test_event_approved.id for e in data)
