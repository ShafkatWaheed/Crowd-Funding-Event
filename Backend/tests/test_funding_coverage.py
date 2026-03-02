"""
Service-level tests for funding/pledges.py.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.user import User, UserRole
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError

from app.services.funding import pledges as pledge_svc


# ===========================================================================
# create_pledge
# ===========================================================================

@pytest.mark.asyncio
async def test_create_pledge_zero_amount(db_session, test_event_approved, test_registration, test_users):
    """amount_cents <= 0 fails."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="amount_cents"):
            await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=0,
            )


@pytest.mark.asyncio
async def test_create_pledge_negative_spots(db_session, test_event_approved, test_registration, test_users):
    """Negative reserved_spots fails."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="negative"):
            await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=1000,
                reserved_spots=-1,
            )


@pytest.mark.asyncio
async def test_create_pledge_cancelled_event(db_session, test_event, test_users):
    """Cannot pledge to cancelled event."""
    customer = test_users["customer"]
    test_event.status = EventStatus.cancelled
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="cancelled"):
            await pledge_svc.create_pledge(
                db_session,
                event_id=test_event.id,
                user=customer,
                amount_cents=1000,
            )


@pytest.mark.asyncio
async def test_create_pledge_completed_event(db_session, test_event, test_users):
    """Cannot pledge to completed event."""
    customer = test_users["customer"]
    test_event.status = EventStatus.completed
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="ended"):
            await pledge_svc.create_pledge(
                db_session,
                event_id=test_event.id,
                user=customer,
                amount_cents=1000,
            )


@pytest.mark.asyncio
async def test_create_pledge_below_minimum(db_session, test_event_approved, test_registration, test_users):
    """Pledge below min_pledge_cents fails."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="at least"):
            await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=100,  # min is 500
            )


@pytest.mark.asyncio
async def test_create_pledge_success(db_session, test_event_approved, test_registration, test_users):
    """Create a valid pledge."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with patch("app.services.payment_gateway.get_gateway") as mock_gw_fn:
            mock_gw = AsyncMock()
            mock_gw.charge = AsyncMock(return_value=type("R", (), {
                "status": "completed",
                "transaction_id": "txn-test-001",
                "authorization_code": "auth-001",
                "receipt_reference": "rcpt-001",
            })())
            mock_gw_fn.return_value = mock_gw
            pledge = await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=1000,
            )
    assert pledge.amount_cents == 1000
    assert pledge.status == FundingStatus.pledged


# ===========================================================================
# unpledge
# ===========================================================================

@pytest.mark.asyncio
async def test_unpledge(db_session, test_event_approved, test_pledge, test_users):
    """Customer unpledges."""
    customer = test_users["customer"]
    result = await pledge_svc.unpledge(
        db_session,
        event_id=test_event_approved.id,
        user=customer,
    )
    assert "refunded_cents" in result
    assert result["pledges_refunded"] >= 1


# ===========================================================================
# refund_all_pledges_for_event
# ===========================================================================

@pytest.mark.asyncio
async def test_refund_all_pledges(db_session, test_event_approved, test_pledge):
    """Refund all pledges for event."""
    count = await pledge_svc.refund_all_pledges_for_event(
        db_session, event_id=test_event_approved.id
    )
    assert count >= 1


@pytest.mark.asyncio
async def test_refund_all_pledges_empty(db_session, test_event_approved):
    """Refund all pledges when none exist."""
    count = await pledge_svc.refund_all_pledges_for_event(
        db_session, event_id=test_event_approved.id
    )
    assert count == 0


# ===========================================================================
# refund_pledge_by_id
# ===========================================================================

@pytest.mark.asyncio
async def test_refund_pledge_by_id(db_session, test_event_approved, test_pledge):
    """Refund specific pledge by ID."""
    result = await pledge_svc.refund_pledge_by_id(
        db_session, event_id=test_event_approved.id, funding_id=test_pledge.id
    )
    assert result == 1


@pytest.mark.asyncio
async def test_refund_pledge_by_id_not_found(db_session, test_event_approved):
    """Refund non-existent pledge."""
    result = await pledge_svc.refund_pledge_by_id(
        db_session, event_id=test_event_approved.id, funding_id=99999
    )
    assert result == 0


# ===========================================================================
# list_pledges_by_user
# ===========================================================================

@pytest.mark.asyncio
async def test_list_pledges_by_user(db_session, test_pledge, test_users):
    """List pledges for customer."""
    customer = test_users["customer"]
    result = await pledge_svc.list_pledges_by_user(db_session, user_id=customer.id)
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_pledges_by_user_sort(db_session, test_pledge, test_users):
    """List pledges with different sort options."""
    customer = test_users["customer"]
    for sort_by in ("newest", "oldest", "amount_high", "amount_low"):
        result = await pledge_svc.list_pledges_by_user(
            db_session, user_id=customer.id, sort_by=sort_by
        )
        assert isinstance(result, (list, tuple))


@pytest.mark.asyncio
async def test_list_pledges_by_user_empty(db_session, test_users):
    """List pledges for user with none."""
    organizer = test_users["organizer"]
    result = await pledge_svc.list_pledges_by_user(db_session, user_id=organizer.id)
    assert len(result) == 0


# ===========================================================================
# list_organizer_pledges
# ===========================================================================

@pytest.mark.asyncio
async def test_list_organizer_pledges(db_session, test_event_approved, test_pledge, test_users):
    """List organizer's event pledges."""
    organizer = test_users["organizer"]
    result = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id
    )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_organizer_pledges_with_status(db_session, test_event_approved, test_pledge, test_users):
    """List organizer pledges with status filter."""
    organizer = test_users["organizer"]
    result = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id, status_filter="pledged"
    )
    assert len(result) >= 1


# ===========================================================================
# list_all_pledges_for_admin
# ===========================================================================

@pytest.mark.asyncio
async def test_list_all_pledges_admin(db_session, test_pledge, test_users):
    """Admin lists all pledges."""
    items, total = await pledge_svc.list_all_pledges_for_admin(db_session)
    assert total >= 1
    assert len(items) >= 1


@pytest.mark.asyncio
async def test_list_all_pledges_admin_search(db_session, test_pledge, test_users):
    """Admin searches pledges."""
    items, total = await pledge_svc.list_all_pledges_for_admin(
        db_session, search="Test"
    )
    assert isinstance(total, int)


# ===========================================================================
# pledge_preview
# ===========================================================================

@pytest.mark.asyncio
async def test_pledge_preview(db_session, test_event_approved, test_users):
    """Preview pledge calculation."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await pledge_svc.pledge_preview(
            db_session,
            event_id=test_event_approved.id,
            user=customer,
            amount_cents=5000,
        )
    assert "amount_cents" in result
    assert "platform_cut_cents" in result
    assert "net_to_organizer_cents" in result
    assert result["amount_cents"] == 5000
