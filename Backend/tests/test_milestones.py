"""Milestones & Early Bird Discounts API tests."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]

BASE = "/api/v1/events"


# =====================================================================
# Funding Milestones CRUD
# =====================================================================


async def test_list_milestones(
    client: AsyncClient,
    test_event_approved,
    test_milestone,
):
    """GET /events/{id}/milestones returns a list (public, no auth required)."""
    r = await client.get(f"{BASE}/{test_event_approved.id}/milestones")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["title"] == "50% Funded"
    assert data[0]["unlock_percent"] == 50


async def test_create_milestone(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """POST /events/{id}/milestones as organizer succeeds (201)."""
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/milestones",
        json={
            "title": "75% Funded",
            "unlock_percent": 75,
            "description": "Almost there!",
            "benefit_description": "Unlocks VIP lounge",
            "sort_order": 1,
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["title"] == "75% Funded"
    assert data["unlock_percent"] == 75
    assert data["description"] == "Almost there!"
    assert data["benefit_description"] == "Unlocks VIP lounge"
    assert "id" in data
    assert data["event_id"] == test_event_approved.id


async def test_create_milestone_not_organizer(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """POST /events/{id}/milestones as customer returns 403."""
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/milestones",
        json={
            "title": "Sneaky Milestone",
            "unlock_percent": 25,
        },
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_update_milestone(
    client: AsyncClient,
    test_event_approved,
    test_milestone,
    test_users,
    auth_headers_organizer,
):
    """PATCH /events/{id}/milestones/{mid} as organizer updates fields."""
    mid = test_milestone.id
    r = await client.patch(
        f"{BASE}/{test_event_approved.id}/milestones/{mid}",
        json={
            "title": "60% Funded",
            "unlock_percent": 60,
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["title"] == "60% Funded"
    assert data["unlock_percent"] == 60


async def test_delete_milestone(
    client: AsyncClient,
    test_event_approved,
    test_milestone,
    test_users,
    auth_headers_organizer,
):
    """DELETE /events/{id}/milestones/{mid} returns 204."""
    mid = test_milestone.id
    r = await client.delete(
        f"{BASE}/{test_event_approved.id}/milestones/{mid}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 204

    # Verify it is gone
    r2 = await client.get(f"{BASE}/{test_event_approved.id}/milestones")
    assert r2.status_code == 200
    ids = [m["id"] for m in r2.json()]
    assert mid not in ids


# =====================================================================
# Milestone Reactions
# =====================================================================


async def test_react_to_milestone(
    client: AsyncClient,
    test_event_approved,
    test_milestone,
    test_users,
    auth_headers_customer,
):
    """POST /events/{id}/milestones/{mid}/react?reaction=like returns 200."""
    mid = test_milestone.id
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/milestones/{mid}/react",
        params={"reaction": "like"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["reaction"] == "like"
    assert "like_count" in data
    assert "dislike_count" in data


async def test_get_my_milestone_reaction(
    client: AsyncClient,
    test_event_approved,
    test_milestone,
    test_users,
    auth_headers_customer,
):
    """GET /events/{id}/milestones/{mid}/my-reaction returns current user's reaction."""
    mid = test_milestone.id

    # First react so there is a reaction to fetch
    await client.post(
        f"{BASE}/{test_event_approved.id}/milestones/{mid}/react",
        params={"reaction": "like"},
        headers=auth_headers_customer,
    )

    r = await client.get(
        f"{BASE}/{test_event_approved.id}/milestones/{mid}/my-reaction",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200


# =====================================================================
# Milestone Snapshots
# =====================================================================


async def test_milestone_snapshots(
    client: AsyncClient,
    test_event_approved,
    test_milestone,
):
    """GET /events/{id}/milestone-snapshots returns a list (may be empty)."""
    r = await client.get(
        f"{BASE}/{test_event_approved.id}/milestone-snapshots",
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


# =====================================================================
# Early Bird Discounts CRUD
# =====================================================================


async def test_list_early_bird_discounts(
    client: AsyncClient,
    test_event_approved,
    test_early_bird_discount,
):
    """GET /events/{id}/early-bird-discounts returns a list (public)."""
    r = await client.get(
        f"{BASE}/{test_event_approved.id}/early-bird-discounts",
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["applies_to"] == "funding"
    assert data[0]["discount_type"] == "percent"
    assert data[0]["value"] == 10


async def test_create_early_bird(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """POST /events/{id}/early-bird-discounts as organizer succeeds (201)."""
    from datetime import datetime, timedelta, timezone

    window_end = (datetime.now(timezone.utc) + timedelta(days=14)).isoformat()

    r = await client.post(
        f"{BASE}/{test_event_approved.id}/early-bird-discounts",
        json={
            "applies_to": "tickets",
            "window_end": window_end,
            "discount_type": "percent",
            "value": 15,
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["applies_to"] == "tickets"
    assert data["discount_type"] == "percent"
    assert data["value"] == 15
    assert "id" in data
    assert data["event_id"] == test_event_approved.id


async def test_update_early_bird(
    client: AsyncClient,
    test_event_approved,
    test_early_bird_discount,
    test_users,
    auth_headers_organizer,
):
    """PATCH /events/{id}/early-bird-discounts/{did} updates discount fields."""
    did = test_early_bird_discount.id
    r = await client.patch(
        f"{BASE}/{test_event_approved.id}/early-bird-discounts/{did}",
        json={
            "value": 20,
            "discount_type": "percent",
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["value"] == 20


async def test_delete_early_bird(
    client: AsyncClient,
    test_event_approved,
    test_early_bird_discount,
    test_users,
    auth_headers_organizer,
):
    """DELETE /events/{id}/early-bird-discounts/{did} returns 204."""
    did = test_early_bird_discount.id
    r = await client.delete(
        f"{BASE}/{test_event_approved.id}/early-bird-discounts/{did}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 204

    # Verify it is gone
    r2 = await client.get(
        f"{BASE}/{test_event_approved.id}/early-bird-discounts",
    )
    assert r2.status_code == 200
    ids = [d["id"] for d in r2.json()]
    assert did not in ids
