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
