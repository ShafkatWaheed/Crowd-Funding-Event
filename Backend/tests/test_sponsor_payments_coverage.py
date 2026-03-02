"""
Service-level tests for sponsor/payments.py — pay_bid, refund_bid,
refund_all_sponsor_payments_for_event, _ensure_sponsor_ticket.
"""
import pytest
from datetime import datetime, timezone
from unittest.mock import patch, AsyncMock

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sponsor import (
    SponsorBid, SponsorPayment, SponsorTicket,
    SponsorshipCategory, BidStatus, PaymentStatus,
)
from app.models.user import User

from app.services.sponsor.payments import pay_bid, refund_bid, refund_all_sponsor_payments_for_event


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


async def _make_bid(db, category, sponsor_user, amount_cents=10000, status=BidStatus.accepted):
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


async def _make_payment(db, bid, amount_cents=None, status=PaymentStatus.completed):
    amt = amount_cents or bid.amount_cents
    payment = SponsorPayment(
        bid_id=bid.id,
        amount_cents=amt,
        platform_cut_cents=amt * 10 // 100,
        net_to_organizer_cents=amt - amt * 10 // 100,
        receipt_number=f"SP-TEST-{bid.id}",
        status=status,
    )
    db.add(payment)
    await db.flush()
    return payment


# ===========================================================================
# pay_bid
# ===========================================================================

@pytest.mark.asyncio
async def test_pay_bid_not_found(db_session, test_users_with_sponsor):
    """Pay non-existent bid returns 404."""
    sponsor = test_users_with_sponsor["sponsor"]
    with pytest.raises(HTTPException) as exc_info:
        await pay_bid(db_session, 99999, sponsor)
    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_pay_bid_not_owner(db_session, test_event_approved, test_users_with_sponsor):
    """Cannot pay someone else's bid."""
    sponsor = test_users_with_sponsor["sponsor"]
    organizer = test_users_with_sponsor["organizer"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.accepted)
    with pytest.raises(HTTPException) as exc_info:
        await pay_bid(db_session, bid.id, organizer)
    assert exc_info.value.status_code == 403


@pytest.mark.asyncio
async def test_pay_bid_not_accepted(db_session, test_event_approved, test_users_with_sponsor):
    """Cannot pay for pending bid."""
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.pending)
    with pytest.raises(HTTPException) as exc_info:
        await pay_bid(db_session, bid.id, sponsor)
    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_pay_bid_already_paid(db_session, test_event_approved, test_users_with_sponsor):
    """Cannot pay an already-paid bid."""
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.accepted)
    await _make_payment(db_session, bid)
    with pytest.raises(HTTPException) as exc_info:
        await pay_bid(db_session, bid.id, sponsor)
    assert exc_info.value.status_code == 409


@pytest.mark.asyncio
async def test_pay_bid_success(db_session, test_event_approved, test_users_with_sponsor):
    """Successful bid payment."""
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, amount_cents=10000, status=BidStatus.accepted)

    mock_result = type("R", (), {
        "status": "completed",
        "transaction_id": "txn-sponsor-001",
        "authorization_code": "auth-001",
    })()

    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10):
        with patch("app.services.platform_settings.get_str", new_callable=AsyncMock, return_value=None):
            with patch("app.services.payment_gateway.get_gateway") as mock_gw_fn:
                mock_gw = AsyncMock()
                mock_gw.charge = AsyncMock(return_value=mock_result)
                mock_gw_fn.return_value = mock_gw
                with patch("app.services.ticket_crypto.encrypt_ticket_qr", return_value="encrypted_qr_data"):
                    payment = await pay_bid(db_session, bid.id, sponsor)

    assert payment.amount_cents == 10000
    assert payment.platform_cut_cents == 1000  # 10% commission
    assert payment.net_to_organizer_cents == 9000
    assert payment.gateway_transaction_id == "txn-sponsor-001"

    # Bid should be marked as paid
    await db_session.refresh(bid)
    assert bid.status == BidStatus.paid


@pytest.mark.asyncio
async def test_pay_bid_gateway_fails(db_session, test_event_approved, test_users_with_sponsor):
    """Payment gateway failure returns 402."""
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, amount_cents=5000, status=BidStatus.accepted)

    mock_result = type("R", (), {
        "status": "failed",
        "failure_reason": "card declined",
        "transaction_id": None,
        "authorization_code": None,
    })()

    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10):
        with patch("app.services.platform_settings.get_str", new_callable=AsyncMock, return_value=None):
            with patch("app.services.payment_gateway.get_gateway") as mock_gw_fn:
                mock_gw = AsyncMock()
                mock_gw.charge = AsyncMock(return_value=mock_result)
                mock_gw_fn.return_value = mock_gw
                with pytest.raises(HTTPException) as exc_info:
                    await pay_bid(db_session, bid.id, sponsor)
    assert exc_info.value.status_code == 402


@pytest.mark.asyncio
async def test_pay_bid_zero_amount(db_session, test_event_approved, test_users_with_sponsor):
    """Zero-amount bid skips gateway call."""
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, amount_cents=0, status=BidStatus.accepted)

    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10):
        with patch("app.services.platform_settings.get_str", new_callable=AsyncMock, return_value=None):
            with patch("app.services.ticket_crypto.encrypt_ticket_qr", return_value="encrypted_qr_data"):
                payment = await pay_bid(db_session, bid.id, sponsor)

    assert payment.amount_cents == 0
    assert payment.gateway_transaction_id is None


# ===========================================================================
# refund_bid
# ===========================================================================

@pytest.mark.asyncio
async def test_refund_bid_not_found(db_session, test_users_with_sponsor):
    """Refund non-existent bid returns 404."""
    organizer = test_users_with_sponsor["organizer"]
    with pytest.raises(HTTPException) as exc_info:
        await refund_bid(db_session, 99999, organizer)
    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_refund_bid_not_paid(db_session, test_event_approved, test_users_with_sponsor):
    """Cannot refund unpaid bid."""
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.accepted)
    with pytest.raises(HTTPException) as exc_info:
        await refund_bid(db_session, bid.id, organizer)
    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_refund_bid_payment_not_found(db_session, test_event_approved, test_users_with_sponsor):
    """Refund bid with paid status but no payment record."""
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.paid)
    with pytest.raises(HTTPException) as exc_info:
        await refund_bid(db_session, bid.id, organizer)
    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_refund_bid_already_refunded(db_session, test_event_approved, test_users_with_sponsor):
    """Cannot refund already-refunded payment."""
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.paid)
    await _make_payment(db_session, bid, status=PaymentStatus.refunded)
    with pytest.raises(HTTPException) as exc_info:
        await refund_bid(db_session, bid.id, organizer)
    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_refund_bid_success(db_session, test_event_approved, test_users_with_sponsor):
    """Successful refund marks payment as refund_processing."""
    organizer = test_users_with_sponsor["organizer"]
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    cat.filled_spots = 1
    await db_session.flush()
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.paid)
    payment = await _make_payment(db_session, bid, status=PaymentStatus.completed)

    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        result = await refund_bid(db_session, bid.id, organizer)

    assert result.status == PaymentStatus.refund_processing
    await db_session.refresh(bid)
    assert bid.status == BidStatus.rejected
    await db_session.refresh(cat)
    assert cat.filled_spots == 0


# ===========================================================================
# refund_all_sponsor_payments_for_event
# ===========================================================================

@pytest.mark.asyncio
async def test_refund_all_no_categories(db_session, test_event_approved):
    """No sponsorship categories — returns 0."""
    count = await refund_all_sponsor_payments_for_event(db_session, test_event_approved.id)
    assert count == 0


@pytest.mark.asyncio
async def test_refund_all_no_paid_bids(db_session, test_event_approved, test_users_with_sponsor):
    """Categories exist but no paid bids — returns 0."""
    await _make_category(db_session, test_event_approved)
    count = await refund_all_sponsor_payments_for_event(db_session, test_event_approved.id)
    assert count == 0


@pytest.mark.asyncio
async def test_refund_all_with_paid_bids(db_session, test_event_approved, test_users_with_sponsor):
    """Refund all paid bids for event."""
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    cat.filled_spots = 1
    await db_session.flush()
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.paid)
    await _make_payment(db_session, bid, status=PaymentStatus.completed)

    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        count = await refund_all_sponsor_payments_for_event(db_session, test_event_approved.id)

    assert count == 1
    await db_session.refresh(bid)
    assert bid.status == BidStatus.rejected


@pytest.mark.asyncio
async def test_refund_all_rejects_accepted_bids(db_session, test_event_approved, test_users_with_sponsor):
    """Refund all also rejects accepted (unpaid) bids."""
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    cat.filled_spots = 1
    await db_session.flush()
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.accepted)

    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        count = await refund_all_sponsor_payments_for_event(db_session, test_event_approved.id)

    # No payments to refund, but accepted bids should be rejected
    assert count == 0
    await db_session.refresh(bid)
    assert bid.status == BidStatus.rejected


@pytest.mark.asyncio
async def test_refund_all_deletes_sponsor_tickets(db_session, test_event_approved, test_users_with_sponsor):
    """Refund all deletes sponsor tickets for event."""
    sponsor = test_users_with_sponsor["sponsor"]
    cat = await _make_category(db_session, test_event_approved)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.paid)
    await _make_payment(db_session, bid, status=PaymentStatus.completed)

    # Create a sponsor ticket
    ticket = SponsorTicket(
        event_id=test_event_approved.id,
        sponsor_user_id=sponsor.id,
        receipt_number="SPT-TEST-001",
    )
    db_session.add(ticket)
    await db_session.flush()

    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        await refund_all_sponsor_payments_for_event(db_session, test_event_approved.id)

    # Sponsor tickets should be deleted
    remaining = (await db_session.execute(
        select(SponsorTicket).where(SponsorTicket.event_id == test_event_approved.id)
    )).scalars().all()
    assert len(remaining) == 0
