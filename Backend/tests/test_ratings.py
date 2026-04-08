"""Ratings & reactions API: create, summary, list, user ratings, react, my-reaction."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── helpers ──

def _ratings_url(event_id: int) -> str:
    return f"/api/v1/events/{event_id}/ratings"


def _ratings_summary_url(event_id: int) -> str:
    return f"/api/v1/events/{event_id}/ratings/summary"


def _user_ratings_url(user_id: int) -> str:
    return f"/api/v1/users/{user_id}/ratings-received"


def _react_url(event_id: int) -> str:
    return f"/api/v1/events/{event_id}/react"


def _my_reaction_url(event_id: int) -> str:
    return f"/api/v1/events/{event_id}/my-reaction"


# ── rating tests ──

async def test_create_rating(
    client: AsyncClient,
    test_event_completed,
    test_users,
    auth_headers_customer,
) -> None:
    """POST /events/{id}/ratings on a completed event creates a rating."""
    r = await client.post(
        _ratings_url(test_event_completed.id),
        json={
            "direction": "customer_to_event",
            "stars": 5,
            "description": "Great event!",
        },
        headers=auth_headers_customer,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["stars"] == 5
    assert "id" in data


async def test_create_rating_not_completed(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
) -> None:
    """POST /events/{id}/ratings on non-completed event returns 400."""
    r = await client.post(
        _ratings_url(test_event_approved.id),
        json={
            "direction": "customer_to_event",
            "stars": 3,
            "description": "Too early",
        },
        headers=auth_headers_customer,
    )
    assert r.status_code == 400
    assert "completed" in r.json()["detail"].lower()


async def test_rating_summary(
    client: AsyncClient,
    test_event_completed,
    test_rating,
    test_users,
    auth_headers_customer,
) -> None:
    """GET /events/{id}/ratings/summary returns aggregate + reviews."""
    r = await client.get(
        _ratings_summary_url(test_event_completed.id),
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "avg_stars" in data
    assert "count" in data
    assert data["count"] >= 1
    assert "top_reviews" in data
    assert "worst_reviews" in data
    assert "my_rating" in data


async def test_list_ratings_organizer(
    client: AsyncClient,
    test_event_completed,
    test_rating,
    test_users,
    auth_headers_organizer,
) -> None:
    """GET /events/{id}/ratings as organizer returns full list."""
    r = await client.get(
        _ratings_url(test_event_completed.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["stars"] == 4  # from test_rating fixture


async def test_user_ratings_summary(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
) -> None:
    """GET /users/{id}/ratings-received returns user rating summary."""
    customer = test_users["customer"]
    r = await client.get(
        _user_ratings_url(customer.id),
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "avg_stars" in data
    assert "count" in data
    assert "top_reviews" in data
    assert "worst_reviews" in data


async def test_create_rating_invalid_direction(
    client: AsyncClient,
    test_event_completed,
    test_users,
    auth_headers_customer,
) -> None:
    """POST /events/{id}/ratings with invalid direction returns 400."""
    r = await client.post(
        _ratings_url(test_event_completed.id),
        json={
            "direction": "invalid_direction",
            "stars": 4,
            "description": "Bad direction",
        },
        headers=auth_headers_customer,
    )
    assert r.status_code == 400
    assert "invalid direction" in r.json()["detail"].lower()


async def test_create_rating_self_rating_prevented(
    client: AsyncClient,
    test_event_completed,
    test_users,
    auth_headers_customer,
) -> None:
    """POST /events/{id}/ratings with rated_user_id == current user returns 400."""
    customer = test_users["customer"]
    r = await client.post(
        _ratings_url(test_event_completed.id),
        json={
            "direction": "customer_to_event",
            "rated_user_id": customer.id,
            "stars": 5,
            "description": "Rating myself",
        },
        headers=auth_headers_customer,
    )
    assert r.status_code == 400
    assert "cannot rate yourself" in r.json()["detail"].lower()


# ── reaction tests (from events/reactions.py) ──

async def test_event_react(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
) -> None:
    """POST /events/{id}/react?reaction=like as customer adds a like."""
    r = await client.post(
        _react_url(test_event_approved.id),
        params={"reaction": "like"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["action"] == "added"
    assert data["reaction"] == "like"
    assert "like_count" in data
    assert "dislike_count" in data


async def test_my_reaction(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
) -> None:
    """GET /events/{id}/my-reaction returns the current user's reaction (or null)."""
    # First, no reaction
    r = await client.get(
        _my_reaction_url(test_event_approved.id),
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["reaction"] is None

    # React, then check again
    await client.post(
        _react_url(test_event_approved.id),
        params={"reaction": "like"},
        headers=auth_headers_customer,
    )
    r2 = await client.get(
        _my_reaction_url(test_event_approved.id),
        headers=auth_headers_customer,
    )
    assert r2.status_code == 200
    assert r2.json()["reaction"] == "like"


# ── Phase 0D gap-fills: reaction toggle & switch ──


async def test_toggle_reaction_off(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
) -> None:
    """POST /events/{id}/react?reaction=like twice removes the reaction."""
    # Add like
    r1 = await client.post(
        _react_url(test_event_approved.id),
        params={"reaction": "like"},
        headers=auth_headers_customer,
    )
    assert r1.status_code == 200
    assert r1.json()["action"] == "added"
    like_count_after_add = r1.json()["like_count"]

    # Same reaction again removes it
    r2 = await client.post(
        _react_url(test_event_approved.id),
        params={"reaction": "like"},
        headers=auth_headers_customer,
    )
    assert r2.status_code == 200
    assert r2.json()["action"] == "removed"
    assert r2.json()["like_count"] == like_count_after_add - 1


async def test_switch_reaction_type(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
) -> None:
    """POST like then dislike switches the reaction and updates counts."""
    # Add like
    r1 = await client.post(
        _react_url(test_event_approved.id),
        params={"reaction": "like"},
        headers=auth_headers_customer,
    )
    assert r1.status_code == 200
    assert r1.json()["action"] == "added"
    like_after = r1.json()["like_count"]
    dislike_after = r1.json()["dislike_count"]

    # Switch to dislike
    r2 = await client.post(
        _react_url(test_event_approved.id),
        params={"reaction": "dislike"},
        headers=auth_headers_customer,
    )
    assert r2.status_code == 200
    assert r2.json()["action"] == "switched"
    assert r2.json()["reaction"] == "dislike"
    # like count should decrease by 1, dislike count should increase by 1
    assert r2.json()["like_count"] == like_after - 1
    assert r2.json()["dislike_count"] == dislike_after + 1
