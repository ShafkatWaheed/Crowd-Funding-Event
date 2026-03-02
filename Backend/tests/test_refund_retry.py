"""
Refund retry service tests: retry individual and batch refunds, count failed.
"""
import pytest
from unittest.mock import patch, AsyncMock

from app.core.exceptions import ConflictError, NotFoundError
from app.models.funding import Funding, FundingStatus
from app.models.sponsor import SponsorBid, SponsorPayment, SponsorshipCategory, PaymentStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.services.refund_retry import (
    retry_ticket_refund,
    retry_pledge_refund,
    retry_sponsor_refund,
    retry_all_for_event,
    count_failed_refunds_for_event,
)

from tests.conftest import SKIP_DB

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── helpers ──


async def _make_failed_ticket(db, event_id, user_id, tier_id):
    sale = TicketSale(
        event_id=event_id,
        user_id=user_id,
        ticket_tier_id=tier_id,
        ticket_code="TKT-FAIL-001",
        receipt_number="REC-FAIL-001",
        amount_paid_cents=2500,
        status=TicketSaleStatus.refund_failed,
    )
    db.add(sale)
    await db.flush()
    return sale


async def _make_failed_pledge(db, event_id, user_id):
    pledge = Funding(
        event_id=event_id,
        user_id=user_id,
        amount_cents=2000,
        platform_cut_cents=200,
        net_to_organizer_cents=1800,
        status=FundingStatus.refund_failed,
        receipt_number="PLG-FAIL-001",
    )
    db.add(pledge)
    await db.flush()
    return pledge


async def _make_failed_sponsor_payment(db, category_id, sponsor_user_id):
    bid = SponsorBid(
        category_id=category_id,
        sponsor_user_id=sponsor_user_id,
        amount_cents=10000,
        proposal_text="Sponsor proposal",
        status="accepted",
    )
    db.add(bid)
    await db.flush()
    payment = SponsorPayment(
        bid_id=bid.id,
        amount_cents=10000,
        platform_cut_cents=1000,
        net_to_organizer_cents=9000,
        receipt_number="SP-FAIL-001",
        status=PaymentStatus.refund_failed,
    )
    db.add(payment)
    await db.flush()
    return payment


# ── tests ──


@patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock)
async def test_retry_ticket_refund_success(
    mock_enqueue,
    db_session,
    test_event_approved,
    test_ticket_tier,
    test_users,
):
    """Retrying a refund_failed ticket sets status to refund_processing and enqueues task."""
    sale = await _make_failed_ticket(
        db_session, test_event_approved.id, test_users["customer"].id, test_ticket_tier.id
    )
    await retry_ticket_refund(db_session, sale.id)

    await db_session.refresh(sale)
    assert sale.status == TicketSaleStatus.refund_processing
    mock_enqueue.assert_awaited_once_with("process_ticket_refund", sale.id)


@patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock)
async def test_retry_pledge_refund_success(
    mock_enqueue,
    db_session,
    test_event_approved,
    test_users,
):
    """Retrying a refund_failed pledge sets status to refund_processing and enqueues task."""
    pledge = await _make_failed_pledge(
        db_session, test_event_approved.id, test_users["customer"].id
    )
    await retry_pledge_refund(db_session, pledge.id)

    await db_session.refresh(pledge)
    assert pledge.status == FundingStatus.refund_processing
    mock_enqueue.assert_awaited_once_with("process_pledge_refund", pledge.id)


@patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock)
async def test_retry_sponsor_refund_success(
    mock_enqueue,
    db_session,
    test_event_approved,
    test_sponsorship_category,
    test_users_with_sponsor,
):
    """Retrying a refund_failed sponsor payment sets status to refund_processing."""
    payment = await _make_failed_sponsor_payment(
        db_session,
        test_sponsorship_category.id,
        test_users_with_sponsor["sponsor"].id,
    )
    await retry_sponsor_refund(db_session, payment.id)

    await db_session.refresh(payment)
    assert payment.status == PaymentStatus.refund_processing
    mock_enqueue.assert_awaited_once_with("process_sponsor_refund", payment.id)


@patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock)
async def test_retry_all_for_event(
    mock_enqueue,
    db_session,
    test_event_approved,
    test_ticket_tier,
    test_users_with_sponsor,
    test_sponsorship_category,
):
    """retry_all_for_event retries all failed refunds and returns counts by type."""
    customer = test_users_with_sponsor["customer"]
    sponsor = test_users_with_sponsor["sponsor"]

    await _make_failed_ticket(
        db_session, test_event_approved.id, customer.id, test_ticket_tier.id
    )
    await _make_failed_pledge(
        db_session, test_event_approved.id, customer.id
    )
    await _make_failed_sponsor_payment(
        db_session, test_sponsorship_category.id, sponsor.id
    )
    await db_session.commit()

    counts = await retry_all_for_event(db_session, test_event_approved.id)

    assert counts["tickets"] == 1
    assert counts["pledges"] == 1
    assert counts["sponsors"] == 1
    assert mock_enqueue.await_count == 3


async def test_count_failed_refunds_for_event(
    db_session,
    test_event_approved,
    test_ticket_tier,
    test_users_with_sponsor,
    test_sponsorship_category,
):
    """count_failed_refunds_for_event returns total count across all types."""
    customer = test_users_with_sponsor["customer"]
    sponsor = test_users_with_sponsor["sponsor"]

    await _make_failed_ticket(
        db_session, test_event_approved.id, customer.id, test_ticket_tier.id
    )
    await _make_failed_pledge(
        db_session, test_event_approved.id, customer.id
    )
    await _make_failed_sponsor_payment(
        db_session, test_sponsorship_category.id, sponsor.id
    )
    await db_session.commit()

    count = await count_failed_refunds_for_event(db_session, test_event_approved.id)
    assert count == 3
