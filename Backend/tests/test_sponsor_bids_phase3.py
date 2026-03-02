"""
Service-level tests for sponsor/bids.py — Phase 3.
Covers: place_bid, update_bid, withdraw_bid, list_bids, accept_bid, reject_bid.
"""
import pytest
from unittest.mock import patch, AsyncMock

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sponsor import SponsorBid, BidStatus, SponsorshipCategory
from app.models.user import User, UserRole
from app.schemas.sponsor import BidCreate, BidUpdate

from app.services.sponsor.bids import (
    place_bid, update_bid, withdraw_bid, list_bids, accept_bid, reject_bid,
)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

async def _make_category(db, event, name="Gold", min_bid=5000, total_spots=3):
    cat = SponsorshipCategory(
        event_id=event.id, name=name, total_spots=total_spots,
        min_bid_cents=min_bid,
    )
    db.add(cat)
    await db.flush()
    return cat


async def _make_bid(db, category, sponsor_user, amount_cents=10000, status=BidStatus.pending):
    bid = SponsorBid(
        category_id=category.id,
        sponsor_user_id=sponsor_user.id,
        amount_cents=amount_cents,
        proposal_text="Test bid",
        status=status,
    )
    db.add(bid)
    await db.flush()
    return bid


# ===========================================================================
# place_bid
# ===========================================================================

@pytest.mark.asyncio
async def test_place_bid_success(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    data = BidCreate(amount_cents=10000, proposal_text="We want to sponsor")
    bid = await place_bid(db_session, cat.id, sponsor, data)
    assert bid.status == BidStatus.pending
    assert bid.amount_cents == 10000


@pytest.mark.asyncio
async def test_place_bid_non_sponsor(db_session, test_event_approved, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    cat = await _make_category(db_session, test_event_approved)
    data = BidCreate(amount_cents=10000, proposal_text="Test")
    with pytest.raises(HTTPException) as exc:
        await place_bid(db_session, cat.id, organizer, data)
    assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_place_bid_below_min(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved, min_bid=5000)
    data = BidCreate(amount_cents=1000, proposal_text="Low bid")
    with pytest.raises(HTTPException) as exc:
        await place_bid(db_session, cat.id, sponsor, data)
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_place_bid_category_full(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved, total_spots=1)
    cat.filled_spots = 1
    await db_session.flush()
    data = BidCreate(amount_cents=10000, proposal_text="Test")
    with pytest.raises(HTTPException) as exc:
        await place_bid(db_session, cat.id, sponsor, data)
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_place_bid_max_active(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved, total_spots=1)
    await _make_bid(db_session, cat, sponsor, status=BidStatus.pending)
    data = BidCreate(amount_cents=10000, proposal_text="Second bid")
    with pytest.raises(HTTPException) as exc:
        await place_bid(db_session, cat.id, sponsor, data)
    assert exc.value.status_code == 409


# ===========================================================================
# update_bid
# ===========================================================================

@pytest.mark.asyncio
async def test_update_bid_success(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved, min_bid=5000)
    bid = await _make_bid(db_session, cat, sponsor, amount_cents=10000)
    data = BidUpdate(amount_cents=15000, proposal_text="Updated proposal")
    updated = await update_bid(db_session, bid.id, sponsor, data)
    assert updated.amount_cents == 15000
    assert updated.proposal_text == "Updated proposal"


@pytest.mark.asyncio
async def test_update_bid_not_found(db_session, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    data = BidUpdate(amount_cents=15000)
    with pytest.raises(HTTPException) as exc:
        await update_bid(db_session, 99999, sponsor, data)
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_update_bid_not_owner(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    organizer = test_users_with_sponsor["organizer"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor)
    data = BidUpdate(amount_cents=15000)
    with pytest.raises(HTTPException) as exc:
        await update_bid(db_session, bid.id, organizer, data)
    assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_update_bid_not_pending(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.accepted)
    data = BidUpdate(amount_cents=15000)
    with pytest.raises(HTTPException) as exc:
        await update_bid(db_session, bid.id, sponsor, data)
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_update_bid_below_min(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved, min_bid=5000)
    bid = await _make_bid(db_session, cat, sponsor, amount_cents=10000)
    data = BidUpdate(amount_cents=1000)
    with pytest.raises(HTTPException) as exc:
        await update_bid(db_session, bid.id, sponsor, data)
    assert exc.value.status_code == 400


# ===========================================================================
# withdraw_bid
# ===========================================================================

@pytest.mark.asyncio
async def test_withdraw_bid_success(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor)
    result = await withdraw_bid(db_session, bid.id, sponsor)
    assert result.status == BidStatus.withdrawn


@pytest.mark.asyncio
async def test_withdraw_bid_not_found(db_session, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    with pytest.raises(HTTPException) as exc:
        await withdraw_bid(db_session, 99999, sponsor)
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_withdraw_bid_not_owner(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    organizer = test_users_with_sponsor["organizer"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor)
    with pytest.raises(HTTPException) as exc:
        await withdraw_bid(db_session, bid.id, organizer)
    assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_withdraw_bid_not_pending(db_session, test_event_approved, test_users_with_sponsor):
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.accepted)
    with pytest.raises(HTTPException) as exc:
        await withdraw_bid(db_session, bid.id, sponsor)
    assert exc.value.status_code == 400


# ===========================================================================
# list_bids
# ===========================================================================

@pytest.mark.asyncio
async def test_list_bids(db_session, test_event_approved, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    await _make_bid(db_session, cat, sponsor, amount_cents=10000)
    await _make_bid(db_session, cat, sponsor, amount_cents=5000, status=BidStatus.withdrawn)
    bids = await list_bids(db_session, cat.id, organizer)
    assert len(bids) == 2


# ===========================================================================
# accept_bid
# ===========================================================================

@pytest.mark.asyncio
async def test_accept_bid_success(db_session, test_event_approved, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor)
    with patch("app.services.ticket_crypto.encrypt_ticket_qr", return_value="encrypted_qr_data"):
        result = await accept_bid(db_session, bid.id, organizer)
    assert result.status == BidStatus.accepted
    await db_session.refresh(cat)
    assert cat.filled_spots == 1


@pytest.mark.asyncio
async def test_accept_bid_not_found(db_session, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    with pytest.raises(HTTPException) as exc:
        await accept_bid(db_session, 99999, organizer)
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_accept_bid_not_pending(db_session, test_event_approved, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.accepted)
    with pytest.raises(HTTPException) as exc:
        await accept_bid(db_session, bid.id, organizer)
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_accept_bid_category_full(db_session, test_event_approved, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved, total_spots=1)
    cat.filled_spots = 1
    await db_session.flush()
    bid = await _make_bid(db_session, cat, sponsor)
    with pytest.raises(HTTPException) as exc:
        await accept_bid(db_session, bid.id, organizer)
    assert exc.value.status_code == 400


# ===========================================================================
# reject_bid
# ===========================================================================

@pytest.mark.asyncio
async def test_reject_bid_success(db_session, test_event_approved, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor)
    result = await reject_bid(db_session, bid.id, organizer)
    assert result.status == BidStatus.rejected


@pytest.mark.asyncio
async def test_reject_bid_not_found(db_session, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    with pytest.raises(HTTPException) as exc:
        await reject_bid(db_session, 99999, organizer)
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_reject_bid_not_pending(db_session, test_event_approved, test_users_with_sponsor):
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.accepted)
    with pytest.raises(HTTPException) as exc:
        await reject_bid(db_session, bid.id, organizer)
    assert exc.value.status_code == 400
