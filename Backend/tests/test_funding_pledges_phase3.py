"""
Service-level tests for funding/pledges.py — Phase 3.

Covers: pledge_preview, create_pledge edge cases, unpledge, refund_all_pledges_for_event,
refund_pledges_for_user_event, list_pledges_by_user, list_organizer_pledges,
list_all_pledges_for_admin, refund_pledge_by_id.
"""
import pytest
from unittest.mock import patch, AsyncMock

from app.core.exceptions import ConflictError
from app.models.event import EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User

from app.services.funding import pledges as pledge_svc


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
_pledge_counter = 0


async def _make_pledge(db, event, user, amount_cents=2000, is_guest=False, status=FundingStatus.pledged):
    global _pledge_counter
    _pledge_counter += 1
    pledge = Funding(
        event_id=event.id,
        user_id=user.id,
        amount_cents=amount_cents,
        platform_cut_cents=amount_cents * 10 // 100,
        net_to_organizer_cents=amount_cents * 90 // 100,
        status=status,
        is_guest=is_guest,
        receipt_number=f"PLG-TEST-P3-{_pledge_counter}",
    )
    db.add(pledge)
    await db.flush()
    return pledge


# ===========================================================================
# pledge_preview
# ===========================================================================


@pytest.mark.asyncio
async def test_pledge_preview_basic(db_session, test_event_approved, test_users):
    """Preview returns correct amount breakdown with 10% commission."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10):
            result = await pledge_svc.pledge_preview(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=5000,
            )
    assert result["amount_cents"] == 5000
    assert result["platform_cut_cents"] == 500
    assert result["net_to_organizer_cents"] == 4500
    assert result["funding_commission_percent"] == 10
    assert result["reserved_spots"] == 0


@pytest.mark.asyncio
async def test_pledge_preview_with_reserved_spots(db_session, test_event_approved, test_users):
    """Preview reflects the reserved_spots parameter passed in."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10):
            result = await pledge_svc.pledge_preview(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=3000,
                reserved_spots=2,
            )
    assert result["reserved_spots"] == 2
    assert result["amount_cents"] == 3000
    assert result["cost_per_spot_cents"] == test_event_approved.min_pledge_cents


@pytest.mark.asyncio
async def test_pledge_preview_different_commission(db_session, test_event_approved, test_users):
    """Preview correctly applies a non-default commission rate."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=15):
            result = await pledge_svc.pledge_preview(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=10000,
            )
    assert result["platform_cut_cents"] == 1500
    assert result["net_to_organizer_cents"] == 8500
    assert result["funding_commission_percent"] == 15


@pytest.mark.asyncio
async def test_pledge_preview_available_spots_for_user(db_session, test_event_approved, test_users):
    """Preview shows available spots for user based on max_reserved_spots_per_user."""
    customer = test_users["customer"]
    test_event_approved.max_reserved_spots_per_user = 5
    await db_session.flush()

    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10):
            result = await pledge_svc.pledge_preview(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=2000,
            )
    assert result["available_spots_for_user"] == 5


# ===========================================================================
# create_pledge — edge cases (basic validation already in test_funding_coverage)
# ===========================================================================


@pytest.mark.asyncio
async def test_create_pledge_payment_failure(db_session, test_event_approved, test_registration, test_users):
    """Payment gateway failure raises ConflictError."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with patch("app.services.payment_gateway.get_gateway") as mock_gw_fn:
            mock_gw = AsyncMock()
            mock_gw.charge = AsyncMock(return_value=type("R", (), {
                "status": "failed",
                "failure_reason": "insufficient funds",
                "transaction_id": None,
                "authorization_code": None,
            })())
            mock_gw_fn.return_value = mock_gw
            with pytest.raises(ConflictError, match="Payment failed"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=1000,
                )


@pytest.mark.asyncio
async def test_create_pledge_guest_no_registration(db_session, test_event_approved, test_users):
    """Pledging without registration creates a guest (is_guest=True) pledge."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with patch("app.services.payment_gateway.get_gateway") as mock_gw_fn:
            mock_gw = AsyncMock()
            mock_gw.charge = AsyncMock(return_value=type("R", (), {
                "status": "completed",
                "transaction_id": "txn-guest-001",
                "authorization_code": "auth-g001",
            })())
            mock_gw_fn.return_value = mock_gw
            pledge = await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=1000,
            )
    assert pledge.is_guest is True
    assert pledge.status == FundingStatus.pledged


# ===========================================================================
# unpledge
# ===========================================================================


@pytest.mark.asyncio
async def test_unpledge_with_pledges(db_session, test_event_approved, test_users):
    """Unpledge refunds all pledged (non-guest) fundings."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=3000)

    result = await pledge_svc.unpledge(
        db_session,
        event_id=test_event_approved.id,
        user=customer,
    )
    assert result["pledges_refunded"] == 2
    assert result["refunded_cents"] == 5000
    assert result["status"] == "refund_processing"


@pytest.mark.asyncio
async def test_unpledge_no_pledges(db_session, test_event_approved, test_users):
    """Unpledge with no pledges returns zeros."""
    customer = test_users["customer"]
    result = await pledge_svc.unpledge(
        db_session,
        event_id=test_event_approved.id,
        user=customer,
    )
    assert result["pledges_refunded"] == 0
    assert result["refunded_cents"] == 0
    assert result["status"] == "completed"


@pytest.mark.asyncio
async def test_unpledge_guest_pledges_not_refunded(db_session, test_event_approved, test_users):
    """Guest pledges (is_guest=True) are not refunded by unpledge."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1000, is_guest=True)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000, is_guest=False)

    result = await pledge_svc.unpledge(
        db_session,
        event_id=test_event_approved.id,
        user=customer,
    )
    # Only the non-guest pledge should be refunded
    assert result["pledges_refunded"] == 1
    assert result["refunded_cents"] == 2000
    assert result["guest_non_refundable_cents"] == 1000


@pytest.mark.asyncio
async def test_unpledge_already_refunded_pledges_skipped(db_session, test_event_approved, test_users):
    """Already-refunded pledges are not re-refunded."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1500, status=FundingStatus.refunded)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2500)

    result = await pledge_svc.unpledge(
        db_session,
        event_id=test_event_approved.id,
        user=customer,
    )
    # Only the pledged one should be refunded; the already-refunded one is skipped.
    assert result["pledges_refunded"] == 1
    assert result["refunded_cents"] == 2500


# ===========================================================================
# refund_all_pledges_for_event
# ===========================================================================


@pytest.mark.asyncio
async def test_refund_all_pledges_for_event(db_session, test_event_approved, test_users):
    """Refunds all pledged fundings for an event (including guests by default)."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=3000, is_guest=True)

    count = await pledge_svc.refund_all_pledges_for_event(
        db_session, event_id=test_event_approved.id, guest_refund=True
    )
    assert count == 2


@pytest.mark.asyncio
async def test_refund_all_pledges_for_event_no_guest(db_session, test_event_approved, test_users):
    """With guest_refund=False, guest pledges are excluded."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1000, is_guest=True)

    count = await pledge_svc.refund_all_pledges_for_event(
        db_session, event_id=test_event_approved.id, guest_refund=False
    )
    # Only the non-guest pledge should be refunded
    assert count == 1


@pytest.mark.asyncio
async def test_refund_all_pledges_for_event_empty(db_session, test_event_approved):
    """No pledges to refund returns 0."""
    count = await pledge_svc.refund_all_pledges_for_event(
        db_session, event_id=test_event_approved.id
    )
    assert count == 0


# ===========================================================================
# refund_pledges_for_user_event
# ===========================================================================


@pytest.mark.asyncio
async def test_refund_pledges_for_user_event(db_session, test_event_approved, test_users):
    """Refund all of a specific user's pledges for an event."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1500)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2500)

    count = await pledge_svc.refund_pledges_for_user_event(
        db_session,
        event_id=test_event_approved.id,
        user_id=customer.id,
    )
    assert count == 2


@pytest.mark.asyncio
async def test_refund_pledges_for_user_event_no_pledges(db_session, test_event_approved, test_users):
    """Returns 0 when user has no pledges."""
    organizer = test_users["organizer"]
    count = await pledge_svc.refund_pledges_for_user_event(
        db_session,
        event_id=test_event_approved.id,
        user_id=organizer.id,
    )
    assert count == 0


@pytest.mark.asyncio
async def test_refund_pledges_for_user_event_only_target_user(db_session, test_event_approved, test_users):
    """Only refunds pledges for the specified user, not other users."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)
    await _make_pledge(db_session, test_event_approved, organizer, amount_cents=3000)

    count = await pledge_svc.refund_pledges_for_user_event(
        db_session,
        event_id=test_event_approved.id,
        user_id=customer.id,
    )
    assert count == 1


# ===========================================================================
# list_pledges_by_user
# ===========================================================================


@pytest.mark.asyncio
async def test_list_pledges_by_user_no_pledges(db_session, test_users):
    """User with no pledges gets an empty list."""
    organizer = test_users["organizer"]
    result = await pledge_svc.list_pledges_by_user(db_session, user_id=organizer.id)
    assert len(result) == 0


@pytest.mark.asyncio
async def test_list_pledges_by_user_with_pledges(db_session, test_event_approved, test_users):
    """User with pledges gets the correct count."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1000)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)

    result = await pledge_svc.list_pledges_by_user(db_session, user_id=customer.id)
    assert len(result) == 2


@pytest.mark.asyncio
async def test_list_pledges_by_user_sort_options(db_session, test_event_approved, test_users):
    """All sort_by options work without error."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1000)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=5000)

    for sort_by in ("newest", "oldest", "amount_high", "amount_low"):
        result = await pledge_svc.list_pledges_by_user(
            db_session, user_id=customer.id, sort_by=sort_by
        )
        assert len(result) == 2

    # amount_high: first result should be 5000
    high = await pledge_svc.list_pledges_by_user(
        db_session, user_id=customer.id, sort_by="amount_high"
    )
    assert high[0].amount_cents >= high[-1].amount_cents

    # amount_low: first result should be 1000
    low = await pledge_svc.list_pledges_by_user(
        db_session, user_id=customer.id, sort_by="amount_low"
    )
    assert low[0].amount_cents <= low[-1].amount_cents


@pytest.mark.asyncio
async def test_list_pledges_by_user_invalid_sort(db_session, test_event_approved, test_users):
    """Invalid sort_by falls back to default (newest) without error."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1000)
    result = await pledge_svc.list_pledges_by_user(
        db_session, user_id=customer.id, sort_by="nonexistent"
    )
    assert len(result) == 1


# ===========================================================================
# list_organizer_pledges
# ===========================================================================


@pytest.mark.asyncio
async def test_list_organizer_pledges_basic(db_session, test_event_approved, test_users):
    """Organizer sees pledges made to their events."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=3000)

    result = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id
    )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_organizer_pledges_status_filter(db_session, test_event_approved, test_users):
    """Filter by pledge status."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1000, status=FundingStatus.refunded)

    pledged = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id, status_filter="pledged"
    )
    refunded = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id, status_filter="refunded"
    )
    assert all(p.status == FundingStatus.pledged for p in pledged)
    assert all(p.status == FundingStatus.refunded for p in refunded)


@pytest.mark.asyncio
async def test_list_organizer_pledges_donation_filter(db_session, test_event_approved, test_users):
    """Filter by donation (is_guest=True)."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1000, is_guest=True)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000, is_guest=False)

    result = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id, status_filter="donation"
    )
    assert all(p.is_guest is True for p in result)


@pytest.mark.asyncio
async def test_list_organizer_pledges_event_id_filter(db_session, test_event_approved, test_users):
    """Filter by specific event_id."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)

    result = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id, event_id=test_event_approved.id
    )
    assert len(result) >= 1
    assert all(p.event_id == test_event_approved.id for p in result)


@pytest.mark.asyncio
async def test_list_organizer_pledges_event_status_filter(db_session, test_event_approved, test_users):
    """Filter by event status."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)

    result = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id, event_status="approved"
    )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_organizer_pledges_invalid_event_status(db_session, test_event_approved, test_users):
    """Invalid event_status is silently ignored."""
    customer = test_users["customer"]
    organizer = test_users["organizer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)

    # Should not raise; invalid status is ignored in the try/except
    result = await pledge_svc.list_organizer_pledges(
        db_session, organizer_id=organizer.id, event_status="not_a_real_status"
    )
    assert isinstance(result, list)


# ===========================================================================
# list_all_pledges_for_admin
# ===========================================================================


@pytest.mark.asyncio
async def test_list_all_pledges_admin_no_results(db_session):
    """Admin list with no pledges returns empty."""
    items, total = await pledge_svc.list_all_pledges_for_admin(db_session)
    assert total == 0
    assert len(items) == 0


@pytest.mark.asyncio
async def test_list_all_pledges_admin_with_results(db_session, test_event_approved, test_users):
    """Admin list returns pledges."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=3000)

    items, total = await pledge_svc.list_all_pledges_for_admin(db_session)
    assert total == 2
    assert len(items) == 2


@pytest.mark.asyncio
async def test_list_all_pledges_admin_status_filter(db_session, test_event_approved, test_users):
    """Admin list filtered by status."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000, status=FundingStatus.pledged)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=1000, status=FundingStatus.refunded)

    items, total = await pledge_svc.list_all_pledges_for_admin(db_session, status="pledged")
    assert total == 1
    assert all(f.status == FundingStatus.pledged for f in items)


@pytest.mark.asyncio
async def test_list_all_pledges_admin_is_donation_true(db_session, test_event_approved, test_users):
    """Admin list filtered by is_donation=True shows only guest pledges."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000, is_guest=True)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=3000, is_guest=False)

    items, total = await pledge_svc.list_all_pledges_for_admin(db_session, is_donation=True)
    assert total == 1
    assert all(f.is_guest is True for f in items)


@pytest.mark.asyncio
async def test_list_all_pledges_admin_is_donation_false(db_session, test_event_approved, test_users):
    """Admin list filtered by is_donation=False shows only non-guest pledges."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000, is_guest=True)
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=3000, is_guest=False)

    items, total = await pledge_svc.list_all_pledges_for_admin(db_session, is_donation=False)
    assert total == 1
    assert all(f.is_guest is False for f in items)


@pytest.mark.asyncio
async def test_list_all_pledges_admin_search_filter(db_session, test_event_approved, test_users):
    """Admin search by event title or user display name."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)

    # Search by event title (partial match)
    items, total = await pledge_svc.list_all_pledges_for_admin(db_session, search="Test Event")
    assert total >= 1

    # Search by user display name
    items2, total2 = await pledge_svc.list_all_pledges_for_admin(db_session, search="Customer")
    assert total2 >= 1


@pytest.mark.asyncio
async def test_list_all_pledges_admin_invalid_status(db_session, test_event_approved, test_users):
    """Invalid status filter is silently ignored (try/except ValueError)."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)

    items, total = await pledge_svc.list_all_pledges_for_admin(db_session, status="bogus_status")
    # Invalid status is ignored, so all pledges are returned
    assert total >= 1


# ===========================================================================
# refund_pledge_by_id
# ===========================================================================


@pytest.mark.asyncio
async def test_refund_pledge_by_id_success(db_session, test_event_approved, test_users):
    """Refund a specific pledge by ID."""
    customer = test_users["customer"]
    pledge = await _make_pledge(db_session, test_event_approved, customer, amount_cents=5000)

    result = await pledge_svc.refund_pledge_by_id(
        db_session, event_id=test_event_approved.id, funding_id=pledge.id
    )
    assert result == 1


@pytest.mark.asyncio
async def test_refund_pledge_by_id_not_found(db_session, test_event_approved):
    """Returns 0 for non-existent funding_id."""
    result = await pledge_svc.refund_pledge_by_id(
        db_session, event_id=test_event_approved.id, funding_id=999999
    )
    assert result == 0


@pytest.mark.asyncio
async def test_refund_pledge_by_id_already_refunded(db_session, test_event_approved, test_users):
    """Idempotent: returns 1 even if pledge is already refunded."""
    customer = test_users["customer"]
    pledge = await _make_pledge(
        db_session, test_event_approved, customer,
        amount_cents=2000, status=FundingStatus.refunded,
    )

    result = await pledge_svc.refund_pledge_by_id(
        db_session, event_id=test_event_approved.id, funding_id=pledge.id
    )
    assert result == 1


@pytest.mark.asyncio
async def test_refund_pledge_by_id_refund_processing(db_session, test_event_approved, test_users):
    """Idempotent: returns 1 if pledge is in refund_processing state."""
    customer = test_users["customer"]
    pledge = await _make_pledge(
        db_session, test_event_approved, customer,
        amount_cents=2000, status=FundingStatus.refund_processing,
    )

    result = await pledge_svc.refund_pledge_by_id(
        db_session, event_id=test_event_approved.id, funding_id=pledge.id
    )
    assert result == 1


@pytest.mark.asyncio
async def test_refund_pledge_by_id_wrong_event(db_session, test_event_approved, test_users):
    """Returns 0 when funding_id exists but for a different event."""
    customer = test_users["customer"]
    pledge = await _make_pledge(db_session, test_event_approved, customer, amount_cents=2000)

    # Use a different event_id that does not match
    result = await pledge_svc.refund_pledge_by_id(
        db_session, event_id=test_event_approved.id + 9999, funding_id=pledge.id
    )
    assert result == 0
