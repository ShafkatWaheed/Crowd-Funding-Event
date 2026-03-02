"""
Service-level tests for sponsor/bids.py, sponsor/payments.py, sponsor_escrow.py.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventStatus
from app.models.sponsor import SponsorBid, BidStatus, SponsorshipCategory, SponsorProfile, SponsorPayment
from app.models.user import User, UserRole
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError


# ===========================================================================
# BIDS: place, update, withdraw, accept, reject, list
# ===========================================================================

@pytest.mark.asyncio
async def test_place_bid_success(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_profile, auth_headers_sponsor):
    """Sponsor places a bid."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids",
        headers=auth_headers_sponsor,
        json={"amount_cents": 10000, "proposal_text": "Great event!"},
    )
    assert resp.status_code in (200, 201)


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
async def test_place_bid_not_sponsor(client, db_session, test_event_approved, test_sponsorship_category, auth_headers_customer):
    """Non-sponsor cannot place bid."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids",
        headers=auth_headers_customer,
        json={"amount_cents": 10000, "proposal_text": "Test"},
    )
    assert resp.status_code in (400, 403)


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
async def test_withdraw_bid(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_sponsor):
    """Sponsor withdraws bid."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids/{test_sponsor_bid.id}/withdraw",
        headers=auth_headers_sponsor,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "withdrawn"


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
async def test_list_bids(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_organizer):
    """Organizer lists bids."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/bids",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


# ===========================================================================
# SPONSOR ESCROW: get_or_create, freeze, unfreeze
# ===========================================================================

@pytest.mark.asyncio
async def test_sponsor_escrow_get_or_create(db_session, test_event_approved):
    """Get or create sponsor escrow."""
    from app.services import sponsor_escrow as se_svc
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow is not None
    assert escrow.event_id == test_event_approved.id


@pytest.mark.asyncio
async def test_sponsor_escrow_idempotent(db_session, test_event_approved):
    """get_or_create is idempotent."""
    from app.services import sponsor_escrow as se_svc
    e1 = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    e2 = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert e1.id == e2.id


@pytest.mark.asyncio
async def test_sponsor_escrow_freeze(db_session, test_event_approved):
    """Freeze sponsor escrow."""
    from app.services import sponsor_escrow as se_svc
    from app.models.escrow import EscrowStatus
    escrow = await se_svc.freeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.frozen


@pytest.mark.asyncio
async def test_sponsor_escrow_unfreeze(db_session, test_event_approved, test_organizer_bank):
    """Unfreeze sponsor escrow."""
    from app.services import sponsor_escrow as se_svc
    from app.models.escrow import EscrowStatus
    await se_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await se_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_sponsor_escrow_release_frozen_fails(db_session, test_event_approved):
    """Cannot release frozen sponsor escrow."""
    from app.services import sponsor_escrow as se_svc
    await se_svc.freeze(db_session, event_id=test_event_approved.id)
    with pytest.raises(ConflictError, match="frozen"):
        await se_svc.release_stage1(db_session, event_id=test_event_approved.id)


# ===========================================================================
# SPONSORSHIP CATEGORIES: CRUD
# ===========================================================================

@pytest.mark.asyncio
async def test_create_category(client, db_session, test_event_approved, auth_headers_organizer):
    """Create sponsorship category."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships",
        headers=auth_headers_organizer,
        json={"name": "Silver", "total_spots": 5, "min_bid_cents": 3000},
    )
    assert resp.status_code in (200, 201)


@pytest.mark.asyncio
async def test_list_categories(client, db_session, test_event_approved, test_sponsorship_category, auth_headers_organizer):
    """List sponsorship categories."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsorships",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_update_category(client, db_session, test_event_approved, test_sponsorship_category, auth_headers_organizer):
    """Update category."""
    resp = await client.patch(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}",
        headers=auth_headers_organizer,
        json={"name": "Diamond"},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_delete_category(client, db_session, test_event_approved, auth_headers_organizer):
    """Delete category with no bids."""
    cat = SponsorshipCategory(
        event_id=test_event_approved.id,
        name="Temp",
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


# ===========================================================================
# SPONSOR VIEWS
# ===========================================================================

@pytest.mark.asyncio
async def test_sponsor_bid_events(client, db_session, test_sponsor_bid, auth_headers_sponsor):
    """Sponsor sees events they bid on."""
    resp = await client.get("/api/v1/me/sponsor-bid-events", headers=auth_headers_sponsor)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_sponsorship_available_events(client, db_session, test_event_approved, test_sponsorship_category, test_users_with_sponsor, auth_headers_sponsor):
    """List events with sponsorship available."""
    resp = await client.get("/api/v1/events/sponsorship-available", headers=auth_headers_sponsor)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_organizer_sponsors_list(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_organizer):
    """Organizer lists sponsors."""
    resp = await client.get("/api/v1/me/organizer-sponsors", headers=auth_headers_organizer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_event_sponsors(client, db_session, test_event_approved, test_sponsorship_category, test_sponsor_bid, auth_headers_organizer):
    """List sponsors for specific event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsors",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200
