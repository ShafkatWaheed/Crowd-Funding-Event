"""
Extended sponsor tests: payment, delegates, tickets, organizer views.
"""
import pytest
from unittest.mock import patch, AsyncMock

from app.models.sponsor import SponsorBid, BidStatus, SponsorPayment, SponsorTicket, SponsorDelegate


# ---------------------------------------------------------------------------
# Sponsor profile edge cases
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_sponsor_profile_not_found(client, db_session, test_users_with_sponsor, auth_headers_customer):
    """Customer has no sponsor profile."""
    resp = await client.get("/api/v1/me/sponsor-profile", headers=auth_headers_customer)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_update_sponsor_profile(client, db_session, test_sponsor_profile, auth_headers_sponsor):
    """Update sponsor profile."""
    resp = await client.patch(
        "/api/v1/me/sponsor-profile",
        headers=auth_headers_sponsor,
        json={"company_name": "Updated Corp"},
    )
    assert resp.status_code == 200
    assert resp.json()["company_name"] == "Updated Corp"


# ---------------------------------------------------------------------------
# Bid operations
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_place_bid_below_minimum(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_profile, auth_headers_sponsor):
    """Bid below minimum amount fails."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids",
        headers=auth_headers_sponsor,
        json={"amount_cents": 100, "proposal_text": "Too low"},
    )
    assert resp.status_code in (400, 409, 422)


@pytest.mark.asyncio
async def test_accept_bid(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, test_users_with_sponsor, auth_headers_organizer):
    """Organizer accepts bid."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}/accept",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "accepted"


@pytest.mark.asyncio
async def test_reject_bid(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_organizer):
    """Organizer rejects bid."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}/reject",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "rejected"


@pytest.mark.asyncio
async def test_withdraw_bid(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_sponsor):
    """Sponsor withdraws bid."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}/withdraw",
        headers=auth_headers_sponsor,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "withdrawn"


@pytest.mark.asyncio
async def test_update_bid(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_sponsor):
    """Sponsor updates bid amount."""
    resp = await client.patch(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}",
        headers=auth_headers_sponsor,
        json={"amount_cents": 15000},
    )
    assert resp.status_code == 200
    assert resp.json()["amount_cents"] == 15000


@pytest.mark.asyncio
async def test_list_bids_as_organizer(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_organizer):
    """Organizer lists bids on category."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


# ---------------------------------------------------------------------------
# Sponsorship categories
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_sponsorship_categories(client, db_session, test_event_approved, test_sponsorship_category, auth_headers_organizer):
    """List sponsorship categories."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsorships",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_create_sponsorship_category(client, db_session, test_event_approved, auth_headers_organizer):
    """Create new sponsorship category."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships",
        headers=auth_headers_organizer,
        json={"name": "Silver", "total_spots": 5, "min_bid_cents": 3000},
    )
    assert resp.status_code in (200, 201)


@pytest.mark.asyncio
async def test_update_sponsorship_category(client, db_session, test_event_approved, test_sponsorship_category, auth_headers_organizer):
    """Update category."""
    resp = await client.patch(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}",
        headers=auth_headers_organizer,
        json={"name": "Platinum"},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_delete_sponsorship_category(client, db_session, test_event_approved, test_sponsorship_category, auth_headers_organizer):
    """Delete category (no bids)."""
    # Need a category with no bids
    from app.models.sponsor import SponsorshipCategory
    cat = SponsorshipCategory(
        event_id=test_event_approved.id,
        name="Temp Cat",
        total_spots=1,
        min_bid_cents=1000,
    )
    db_session.add(cat)
    await db_session.commit()
    resp = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{cat.id}",
        headers=auth_headers_organizer,
    )
    assert resp.status_code in (200, 204)


# ---------------------------------------------------------------------------
# Sponsor organizer views
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_sponsor_bid_events(client, db_session, test_sponsor_bid, auth_headers_sponsor):
    """Sponsor sees events they've bid on."""
    resp = await client.get("/api/v1/me/sponsor-bid-events", headers=auth_headers_sponsor)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_sponsorship_available_events(client, db_session, test_event_approved, test_sponsorship_category, test_users_with_sponsor, auth_headers_sponsor):
    """List events with sponsorship available."""
    resp = await client.get("/api/v1/events/sponsorship-available", headers=auth_headers_sponsor)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_organizer_sponsors_list(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_organizer):
    """Organizer lists their sponsors."""
    resp = await client.get("/api/v1/me/organizer-sponsors", headers=auth_headers_organizer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_event_sponsors_list(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_organizer):
    """List sponsors for specific event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsors",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Sponsor tickets
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_sponsor_tickets(client, db_session, test_sponsor_profile, auth_headers_sponsor):
    """Sponsor lists their tickets (may be empty)."""
    resp = await client.get("/api/v1/me/sponsor-tickets", headers=auth_headers_sponsor)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Sponsor templates
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_sponsor_template(client, db_session, test_users_with_sponsor, auth_headers_organizer):
    """Organizer creates sponsor category template."""
    resp = await client.post(
        "/api/v1/me/sponsor-category-templates",
        headers=auth_headers_organizer,
        json={"name": "Gold Template", "total_spots": 2, "min_bid_cents": 5000},
    )
    assert resp.status_code in (200, 201)


@pytest.mark.asyncio
async def test_list_sponsor_templates(client, db_session, test_users, auth_headers_organizer):
    """Organizer lists templates."""
    resp = await client.get(
        "/api/v1/me/sponsor-category-templates",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
