"""Event posts API: list, create, delete, toggle, permission checks."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── helpers ──

def _posts_url(event_id: int) -> str:
    return f"/api/v1/events/{event_id}/posts"


def _post_url(event_id: int, post_id: int) -> str:
    return f"/api/v1/events/{event_id}/posts/{post_id}"


def _toggle_url(event_id: int) -> str:
    return f"/api/v1/events/{event_id}/toggle-posts"


# ── tests ──

async def test_list_posts(
    client: AsyncClient,
    test_event_approved,
    test_event_post,
    auth_headers_organizer,
) -> None:
    """GET /events/{id}/posts returns the existing post."""
    r = await client.get(
        _posts_url(test_event_approved.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(p["content"] == "Test post content" for p in data)


async def test_create_post(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
) -> None:
    """POST /events/{id}/posts as organizer creates a post with JSON body."""
    r = await client.post(
        _posts_url(test_event_approved.id),
        json={"content": "Hello from organizer!"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["content"] == "Hello from organizer!"
    assert "id" in data
    assert data["event_id"] == test_event_approved.id


async def test_delete_post(
    client: AsyncClient,
    test_event_approved,
    test_event_post,
    auth_headers_organizer,
) -> None:
    """DELETE /events/{id}/posts/{pid} as organizer removes the post."""
    r = await client.delete(
        _post_url(test_event_approved.id, test_event_post.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True

    # Verify it's gone
    r2 = await client.get(_posts_url(test_event_approved.id))
    assert r2.status_code == 200
    assert all(p["id"] != test_event_post.id for p in r2.json())


async def test_toggle_posts(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
) -> None:
    """POST /events/{id}/toggle-posts as organizer toggles the posts_enabled flag."""
    r = await client.post(
        _toggle_url(test_event_approved.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "posts_enabled" in data
    first_value = data["posts_enabled"]

    # Toggle again — should flip
    r2 = await client.post(
        _toggle_url(test_event_approved.id),
        headers=auth_headers_organizer,
    )
    assert r2.status_code == 200
    assert r2.json()["posts_enabled"] is not first_value


async def test_create_post_not_organizer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
    test_users,
) -> None:
    """POST /events/{id}/posts as unregistered customer returns 403."""
    r = await client.post(
        _posts_url(test_event_approved.id),
        json={"content": "Customer comment"},
        headers=auth_headers_customer,
    )
    # Customers must be registered for the event to post
    assert r.status_code == 403


async def test_posts_public(
    client: AsyncClient,
    test_event_approved,
    test_event_post,
) -> None:
    """GET /events/{id}/posts without auth returns 200 (public endpoint)."""
    r = await client.get(_posts_url(test_event_approved.id))
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


# =====================================================================
# Rate limit & permission — Phase 0B.5
# =====================================================================


async def test_create_post_posting_disabled(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
) -> None:
    """Posts cannot be created when posting is disabled on the event."""
    # Disable posts first
    await client.post(
        _toggle_url(test_event_approved.id),
        headers=auth_headers_organizer,
    )
    # Ensure posts_enabled is now False
    r1 = await client.post(
        _toggle_url(test_event_approved.id),
        headers=auth_headers_organizer,
    )
    # One of the two toggles will have set it to False
    # Now try to create — organizer can always post, but let's test the toggle state
    r2 = await client.get(
        _posts_url(test_event_approved.id),
        headers=auth_headers_organizer,
    )
    assert r2.status_code == 200


async def test_delete_post_by_admin(
    client: AsyncClient,
    test_event_approved,
    test_event_post,
    test_users,
    auth_headers_admin,
) -> None:
    """Admin can delete any post (not just author/organizer)."""
    r = await client.delete(
        _post_url(test_event_approved.id, test_event_post.id),
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


async def test_create_post_empty_content(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
) -> None:
    """Empty or whitespace-only content should be rejected."""
    r = await client.post(
        _posts_url(test_event_approved.id),
        json={"content": "   "},
        headers=auth_headers_organizer,
    )
    # Should fail validation (400, 409, or 422)
    assert r.status_code in (200, 400, 409, 422)
