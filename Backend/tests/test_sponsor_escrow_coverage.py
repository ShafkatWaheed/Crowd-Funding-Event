"""
Service-level tests for sponsor_escrow.py — get_or_create, release stages,
freeze, unfreeze, list_all, auto-trigger check_and_release_stage1/2/3.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.escrow import SponsorEscrow, EscrowStatus
from app.models.event import Event, EventStatus
from app.models.sponsor import (
    SponsorBid, SponsorPayment, SponsorshipCategory, BidStatus, PaymentStatus,
)
from app.core.exceptions import ConflictError

from app.services import sponsor_escrow as se_svc


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

async def _make_sponsor_payment(db, event, sponsor_user, amount_cents=10000):
    """Create category + bid + payment to give the escrow something to hold."""
    cat = SponsorshipCategory(
        event_id=event.id, name="Gold", total_spots=3, min_bid_cents=5000,
    )
    db.add(cat)
    await db.flush()
    bid = SponsorBid(
        category_id=cat.id, sponsor_user_id=sponsor_user.id,
        amount_cents=amount_cents, proposal_text="Test", status=BidStatus.paid,
    )
    db.add(bid)
    await db.flush()
    payment = SponsorPayment(
        bid_id=bid.id, amount_cents=amount_cents,
        platform_cut_cents=amount_cents * 10 // 100,
        net_to_organizer_cents=amount_cents - amount_cents * 10 // 100,
        receipt_number=f"SP-TEST-{bid.id}", status=PaymentStatus.completed,
    )
    db.add(payment)
    await db.flush()
    return payment


# ===========================================================================
# get_or_create, refresh_total
# ===========================================================================

@pytest.mark.asyncio
async def test_get_or_create(db_session, test_event_approved):
    """Create sponsor escrow."""
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow is not None
    assert escrow.event_id == test_event_approved.id


@pytest.mark.asyncio
async def test_get_or_create_idempotent(db_session, test_event_approved):
    """get_or_create is idempotent."""
    e1 = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    e2 = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert e1.id == e2.id


@pytest.mark.asyncio
async def test_refresh_total(db_session, test_event_approved, test_users_with_sponsor):
    """Refresh total recalculates from payments."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"], 10000)
    escrow = await se_svc.refresh_total(db_session, test_event_approved.id)
    assert escrow.total_held_cents == 9000  # net_to_organizer = 10000 - 10%


@pytest.mark.asyncio
async def test_refresh_total_empty(db_session, test_event_approved):
    """Refresh total with no payments."""
    escrow = await se_svc.refresh_total(db_session, test_event_approved.id)
    assert escrow.total_held_cents == 0


# ===========================================================================
# freeze / unfreeze
# ===========================================================================

@pytest.mark.asyncio
async def test_freeze(db_session, test_event_approved):
    """Freeze sponsor escrow."""
    escrow = await se_svc.freeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.frozen


@pytest.mark.asyncio
async def test_unfreeze(db_session, test_event_approved, test_organizer_bank):
    """Unfreeze sponsor escrow."""
    await se_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await se_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_release_frozen_fails(db_session, test_event_approved):
    """Cannot release frozen sponsor escrow."""
    await se_svc.freeze(db_session, event_id=test_event_approved.id)
    with pytest.raises(ConflictError, match="frozen"):
        await se_svc.release_stage1(db_session, event_id=test_event_approved.id)


# ===========================================================================
# reject_if_blocked
# ===========================================================================

@pytest.mark.asyncio
async def test_reject_if_refunded(db_session, test_event_approved):
    """Cannot release refunded sponsor escrow."""
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.status = EscrowStatus.refunded
    await db_session.flush()
    with pytest.raises(ConflictError, match="refunded"):
        se_svc._reject_if_blocked(escrow)


# ===========================================================================
# release stages (via escrow_base.generic_release_stage)
# ===========================================================================

@pytest.mark.asyncio
async def test_release_stage1(db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank):
    """Release stage 1."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"], 20000)
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        escrow = await se_svc.release_stage1(db_session, event_id=test_event_approved.id)
    assert escrow.stage1_released_at is not None
    assert escrow.status == EscrowStatus.partially_released


@pytest.mark.asyncio
async def test_release_stage2_requires_stage1(db_session, test_event_approved, test_users_with_sponsor):
    """Cannot release stage 2 before stage 1."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"])
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        with pytest.raises(ConflictError, match="Stage 1"):
            await se_svc.release_stage2(db_session, event_id=test_event_approved.id)


@pytest.mark.asyncio
async def test_release_stage1_duplicate_fails(db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank):
    """Cannot release stage 1 twice."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"])
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        await se_svc.release_stage1(db_session, event_id=test_event_approved.id)
        with pytest.raises(ConflictError, match="already released"):
            await se_svc.release_stage1(db_session, event_id=test_event_approved.id)


# ===========================================================================
# list_all
# ===========================================================================

@pytest.mark.asyncio
async def test_list_all(db_session, test_event_approved):
    """List all sponsor escrows."""
    await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.flush()
    items, total = await se_svc.list_all(db_session)
    assert total >= 1


@pytest.mark.asyncio
async def test_list_all_with_search(db_session, test_event_approved):
    """List escrows with search."""
    await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.flush()
    items, total = await se_svc.list_all(db_session, search="Test")
    assert isinstance(total, int)


# ===========================================================================
# check_and_release_stage1 (auto-trigger)
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage1_disabled(db_session, test_event_approved):
    """Stage 1 auto-trigger disabled returns None."""
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_no_event(db_session):
    """Stage 1 auto-trigger with non-existent event returns None."""
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage1(db_session, event_id=99999)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_already_released(db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank):
    """Stage 1 auto-trigger when already released returns None."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"])
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        await se_svc.release_stage1(db_session, event_id=test_event_approved.id)
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_event_live(db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank):
    """Stage 1 auto-trigger fires when event is live."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"])
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.stage1_auto_release = True
    test_event_approved.status = EventStatus.live
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "event_live"

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is not None
    assert result.stage1_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage1_not_live_yet(db_session, test_event_approved, test_users_with_sponsor):
    """Stage 1 auto-trigger skips when event is not live."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"])
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.stage1_auto_release = True
    await db_session.flush()  # event status is still "approved"

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "event_live"

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


# ===========================================================================
# check_and_release_stage2 (auto-trigger)
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage2_disabled(db_session, test_event_approved):
    """Stage 2 auto-trigger disabled returns None."""
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await se_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage2_no_stage1(db_session, test_event_approved, test_users_with_sponsor):
    """Stage 2 auto-trigger skips when stage 1 not yet released."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"])
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.stage2_auto_release = True
    await db_session.flush()

    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


# ===========================================================================
# check_and_release_stage3 (auto-trigger)
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage3_disabled(db_session, test_event_approved):
    """Stage 3 auto-trigger disabled returns None."""
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await se_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_no_stage2(db_session, test_event_approved, test_users_with_sponsor):
    """Stage 3 auto-trigger skips when stage 2 not yet released."""
    await _make_sponsor_payment(db_session, test_event_approved, test_users_with_sponsor["sponsor"])
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.stage3_auto_release = True
    await db_session.flush()

    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_check_bank_guard_no_bank(db_session, test_event_approved, test_users_with_sponsor):
    """Bank guard blocks release when no verified bank."""
    result = await se_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is False


@pytest.mark.asyncio
async def test_check_bank_guard_with_bank(db_session, test_event_approved, test_organizer_bank):
    """Bank guard allows release when verified bank exists."""
    result = await se_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is True


@pytest.mark.asyncio
async def test_check_bank_guard_no_event(db_session):
    """Bank guard returns False for non-existent event."""
    result = await se_svc._check_bank_guard(db_session, 99999, stage=1)
    assert result is False
