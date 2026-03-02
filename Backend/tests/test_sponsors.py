"""Sponsor API: profile, categories, templates, bids (place/update/withdraw/accept/reject/list)."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# =====================================================================
# Sponsor Profile  (/me/sponsor-profile)
# =====================================================================


async def test_create_sponsor_profile(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """POST /me/sponsor-profile creates a new profile for a sponsor user."""
    r = await client.post(
        "/api/v1/me/sponsor-profile",
        json={
            "company_name": "Acme Corp",
            "contact_name": "Jane Doe",
            "profession": "Marketing",
        },
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["company_name"] == "Acme Corp"
    assert data["contact_name"] == "Jane Doe"
    assert data["profession"] == "Marketing"
    assert "id" in data


async def test_create_sponsor_profile_duplicate(
    client: AsyncClient,
    test_sponsor_profile,
    auth_headers_sponsor,
):
    """POST /me/sponsor-profile when profile already exists returns 409."""
    r = await client.post(
        "/api/v1/me/sponsor-profile",
        json={
            "company_name": "Duplicate Corp",
            "contact_name": "Dup Person",
            "profession": "Sales",
        },
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 409


async def test_get_sponsor_profile(
    client: AsyncClient,
    test_sponsor_profile,
    auth_headers_sponsor,
):
    """GET /me/sponsor-profile returns the sponsor's profile."""
    r = await client.get(
        "/api/v1/me/sponsor-profile",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["company_name"] == "Test Corp"
    assert data["id"] == test_sponsor_profile.id


async def test_get_sponsor_profile_not_found(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """GET /me/sponsor-profile when no profile exists returns 404."""
    r = await client.get(
        "/api/v1/me/sponsor-profile",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 404


async def test_update_sponsor_profile(
    client: AsyncClient,
    test_sponsor_profile,
    auth_headers_sponsor,
):
    """PATCH /me/sponsor-profile updates fields."""
    r = await client.patch(
        "/api/v1/me/sponsor-profile",
        json={"company_name": "Updated Corp", "website_url": "https://updated.com"},
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["company_name"] == "Updated Corp"
    assert data["website_url"] == "https://updated.com"
    # Unchanged fields should remain
    assert data["contact_name"] == "Sponsor Person"


# =====================================================================
# Sponsorship Categories  (/events/{event_id}/sponsorships)
# =====================================================================


async def test_list_categories_as_sponsor(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """GET /events/{id}/sponsorships as sponsor returns categories."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsorships",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["name"] == "Gold Sponsor"


async def test_list_categories_forbidden_for_customer(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """GET /events/{id}/sponsorships as customer returns 403."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsorships",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_create_category_as_organizer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
    test_users,
):
    """POST /events/{id}/sponsorships as organizer creates a category."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships",
        json={"name": "Silver Sponsor", "total_spots": 5, "min_bid_cents": 2500},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Silver Sponsor"
    assert data["total_spots"] == 5
    assert data["min_bid_cents"] == 2500


async def test_create_category_as_admin(
    client: AsyncClient,
    test_event_approved,
    auth_headers_admin,
    test_users,
):
    """POST /events/{id}/sponsorships as admin succeeds."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships",
        json={"name": "Platinum", "total_spots": 1, "min_bid_cents": 50000},
        headers=auth_headers_admin,
    )
    assert r.status_code == 201
    assert r.json()["name"] == "Platinum"


async def test_delete_category_as_organizer(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer,
    test_users,
):
    """DELETE /events/{id}/sponsorships/{cat_id} as organizer returns 204."""
    r = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 204


async def test_delete_category_forbidden_for_sponsor(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
    test_users_with_sponsor,
):
    """DELETE /events/{id}/sponsorships/{cat_id} as sponsor returns 403."""
    r = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 403


# =====================================================================
# Sponsor Category Templates  (/me/sponsor-category-templates)
# =====================================================================


async def test_create_template(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """POST /me/sponsor-category-templates creates a template."""
    r = await client.post(
        "/api/v1/me/sponsor-category-templates",
        json={"name": "My Template", "total_spots": 2, "min_bid_cents": 1000},
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "My Template"
    assert data["is_template"] is True
    assert data["total_spots"] == 2
    assert data["min_bid_cents"] == 1000


async def test_list_templates_empty(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """GET /me/sponsor-category-templates with no templates returns empty list."""
    r = await client.get(
        "/api/v1/me/sponsor-category-templates",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert r.json() == []


async def test_list_templates_with_data(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """GET /me/sponsor-category-templates returns previously created templates."""
    # Create a template first
    await client.post(
        "/api/v1/me/sponsor-category-templates",
        json={"name": "Bronze", "total_spots": 10, "min_bid_cents": 500},
        headers=auth_headers_sponsor,
    )
    r = await client.get(
        "/api/v1/me/sponsor-category-templates",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data) == 1
    assert data[0]["name"] == "Bronze"


async def test_delete_template(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """DELETE /me/sponsor-category-templates/{tid} removes the template."""
    # Create then delete
    create_r = await client.post(
        "/api/v1/me/sponsor-category-templates",
        json={"name": "Temp", "total_spots": 1, "min_bid_cents": 100},
        headers=auth_headers_sponsor,
    )
    tid = create_r.json()["id"]

    r = await client.delete(
        f"/api/v1/me/sponsor-category-templates/{tid}",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 204

    # Verify it is gone
    list_r = await client.get(
        "/api/v1/me/sponsor-category-templates",
        headers=auth_headers_sponsor,
    )
    assert list_r.status_code == 200
    assert len(list_r.json()) == 0


# =====================================================================
# Bids  (/events/{eid}/sponsorships/{cid}/bids)
# =====================================================================


def _bids_url(event_id: int, cat_id: int) -> str:
    return f"/api/v1/events/{event_id}/sponsorships/{cat_id}/bids"


def _bid_url(event_id: int, cat_id: int, bid_id: int) -> str:
    return f"/api/v1/events/{event_id}/sponsorships/{cat_id}/bids/{bid_id}"


async def test_place_bid(
    client: AsyncClient,
    test_sponsor_profile,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
):
    """POST .../bids places a new bid for a sponsor."""
    r = await client.post(
        _bids_url(test_event_approved.id, test_sponsorship_category.id),
        json={"amount_cents": 7500, "proposal_text": "We love this event!"},
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["amount_cents"] == 7500
    assert data["status"] == "pending"
    assert data["proposal_text"] == "We love this event!"
    assert "sponsor_profile" in data


async def test_place_bid_below_minimum(
    client: AsyncClient,
    test_sponsor_profile,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
):
    """POST .../bids with amount below min_bid_cents returns 400."""
    r = await client.post(
        _bids_url(test_event_approved.id, test_sponsorship_category.id),
        json={"amount_cents": 100, "proposal_text": "Lowball"},
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 400


async def test_place_bid_forbidden_for_customer(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_customer,
    test_users,
):
    """POST .../bids as customer returns 403."""
    r = await client.post(
        _bids_url(test_event_approved.id, test_sponsorship_category.id),
        json={"amount_cents": 6000, "proposal_text": "I'm a customer"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_update_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
):
    """PATCH .../bids/{bid_id} updates amount and proposal."""
    r = await client.patch(
        _bid_url(test_event_approved.id, test_sponsorship_category.id, test_sponsor_bid.id),
        json={"amount_cents": 15000, "proposal_text": "Updated proposal"},
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["amount_cents"] == 15000
    assert data["proposal_text"] == "Updated proposal"


async def test_withdraw_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
):
    """POST .../bids/{bid_id}/withdraw sets status to withdrawn."""
    r = await client.post(
        _bid_url(test_event_approved.id, test_sponsorship_category.id, test_sponsor_bid.id) + "/withdraw",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert r.json()["status"] == "withdrawn"


async def test_accept_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """POST .../bids/{bid_id}/accept as organizer sets status to accepted."""
    r = await client.post(
        _bid_url(test_event_approved.id, test_sponsorship_category.id, test_sponsor_bid.id) + "/accept",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["status"] == "accepted"


async def test_reject_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """POST .../bids/{bid_id}/reject as organizer sets status to rejected."""
    r = await client.post(
        _bid_url(test_event_approved.id, test_sponsorship_category.id, test_sponsor_bid.id) + "/reject",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["status"] == "rejected"


async def test_list_bids_as_organizer(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_organizer,
    test_users_with_sponsor,
):
    """GET .../bids as organizer returns all bids for the category."""
    r = await client.get(
        _bids_url(test_event_approved.id, test_sponsorship_category.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["id"] == test_sponsor_bid.id


async def test_accept_bid_forbidden_for_sponsor(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsorship_category,
    test_event_approved,
    auth_headers_sponsor,
):
    """POST .../bids/{bid_id}/accept as sponsor returns 403."""
    r = await client.post(
        _bid_url(test_event_approved.id, test_sponsorship_category.id, test_sponsor_bid.id) + "/accept",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 403


# =====================================================================
# Auth guard: unauthenticated requests
# =====================================================================


async def test_sponsor_profile_unauthenticated(client: AsyncClient, test_users):
    """GET /me/sponsor-profile without auth returns 401 or 403."""
    r = await client.get("/api/v1/me/sponsor-profile")
    assert r.status_code in (401, 403)


async def test_place_bid_unauthenticated(
    client: AsyncClient,
    test_sponsorship_category,
    test_event_approved,
):
    """POST .../bids without auth returns 401 or 403."""
    r = await client.post(
        _bids_url(test_event_approved.id, test_sponsorship_category.id),
        json={"amount_cents": 5000, "proposal_text": "No auth"},
    )
    assert r.status_code in (401, 403)
