"""Tests for event reactions: like/dislike, toggle, switch, my-reaction."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── Like / Dislike ────────────────────────────────────────────────


async def test_like_event(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """POST /{event_id}/react?reaction=like creates a like."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/react?reaction=like",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["reaction"] == "like"
    assert data["like_count"] >= 1


async def test_dislike_event(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """POST /{event_id}/react?reaction=dislike creates a dislike."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/react?reaction=dislike",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["reaction"] == "dislike"
    assert data["dislike_count"] >= 1


# ── Toggle (same reaction removes it) ────────────────────────────


async def test_toggle_like_removes_it(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """Sending 'like' twice removes the reaction."""
    url = f"/api/v1/events/{test_event_approved.id}/react?reaction=like"
    await client.post(url, headers=auth_headers_customer)
    r = await client.post(url, headers=auth_headers_customer)
    assert r.status_code == 200
    data = r.json()
    assert data["action"] == "removed"
    assert data["like_count"] == 0


# ── Switch (different reaction switches) ──────────────────────────


async def test_switch_like_to_dislike(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """Switching from like to dislike changes the reaction."""
    base = f"/api/v1/events/{test_event_approved.id}/react"
    await client.post(f"{base}?reaction=like", headers=auth_headers_customer)
    r = await client.post(f"{base}?reaction=dislike", headers=auth_headers_customer)
    assert r.status_code == 200
    data = r.json()
    assert data["reaction"] == "dislike"
    assert data["action"] == "switched"


# ── Invalid reaction ──────────────────────────────────────────────


async def test_invalid_reaction_rejected(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """Non-like/dislike reaction returns 400."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/react?reaction=love",
        headers=auth_headers_customer,
    )
    assert r.status_code == 400


# ── My reaction ───────────────────────────────────────────────────


async def test_my_reaction_none_initially(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """GET /{event_id}/my-reaction returns null when no reaction."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/my-reaction",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["reaction"] is None


async def test_my_reaction_after_like(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """GET /{event_id}/my-reaction returns 'like' after liking."""
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/react?reaction=like",
        headers=auth_headers_customer,
    )
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/my-reaction",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["reaction"] == "like"


# ── Auth required ─────────────────────────────────────────────────


async def test_react_unauthenticated(
    client: AsyncClient,
    test_event_approved,
    test_users,
):
    """POST /{event_id}/react without auth returns 401."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/react?reaction=like",
    )
    assert r.status_code == 401


async def test_my_reaction_unauthenticated(
    client: AsyncClient,
    test_event_approved,
    test_users,
):
    """GET /{event_id}/my-reaction without auth returns 401."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/my-reaction",
    )
    assert r.status_code == 401


# ── Non-existent event ────────────────────────────────────────────


async def test_react_nonexistent_event(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """POST /99999/react on missing event returns 404."""
    r = await client.post(
        "/api/v1/events/99999/react?reaction=like",
        headers=auth_headers_customer,
    )
    assert r.status_code == 404
