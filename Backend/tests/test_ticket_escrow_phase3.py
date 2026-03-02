"""
Service-level tests for ticket_escrow.py auto-trigger functions:
  - check_and_release_stage1
  - check_and_release_stage2
  - check_and_release_stage3
  - _check_bank_guard
  - Direct release_stage1/2/3, freeze, unfreeze, list_all
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.escrow import TicketEscrow, EscrowStatus
from app.models.event import Event, EventStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
from app.models.dispute import Dispute, DisputeStatus
from app.core.exceptions import ConflictError

import app.services.ticket_escrow as te_svc

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_ticket_counter = 0


async def _make_ticket_sale(
    db, *, event_id, user_id, tier_id,
    amount_paid_cents=2500, commission_cents=250,
    status=TicketSaleStatus.purchased,
):
    """Create a TicketSale with unique ticket_code and receipt_number."""
    global _ticket_counter
    _ticket_counter += 1
    sale = TicketSale(
        event_id=event_id,
        user_id=user_id,
        ticket_tier_id=tier_id,
        ticket_code=f"TKT-P3-{_ticket_counter:04d}",
        receipt_number=f"REC-P3-{_ticket_counter:04d}",
        amount_paid_cents=amount_paid_cents,
        commission_cents=commission_cents,
        net_to_organizer_cents=amount_paid_cents - commission_cents,
        status=status,
    )
    db.add(sale)
    await db.flush()
    return sale


async def _make_tier(db, event_id):
    """Create a unique TicketTier for the given event."""
    global _ticket_counter
    _ticket_counter += 1
    tier = TicketTier(
        event_id=event_id,
        name=f"Tier-P3-{_ticket_counter}",
        price_cents=2500,
        display_order=0,
    )
    db.add(tier)
    await db.flush()
    return tier


async def _release_stage1(db, event_id, pct=30):
    """Helper that patches settings_svc.get_int for stage 1 release."""
    async def mock_get_int(db_arg, key, **kw):
        return {"ticket_escrow_stage1_percent": pct}.get(key, 30)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        return await te_svc.release_stage1(db, event_id=event_id)


async def _release_stage2(db, event_id, pct=40):
    """Helper that patches settings_svc.get_int for stage 2 release."""
    async def mock_get_int(db_arg, key, **kw):
        return {"ticket_escrow_stage2_percent": pct}.get(key, 40)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        return await te_svc.release_stage2(db, event_id=event_id)


async def _release_stage3(db, event_id, pct=30):
    """Helper that patches settings_svc.get_int for stage 3 release."""
    async def mock_get_int(db_arg, key, **kw):
        return {"ticket_escrow_stage3_percent": pct}.get(key, 30)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        return await te_svc.release_stage3(db, event_id=event_id)


def _make_event_completed_with_old_end(event, days_ago=30):
    """Mark event as completed with end_time in the past."""
    event.status = EventStatus.completed
    event.end_time = datetime.now(timezone.utc) - timedelta(days=days_ago)


# ===========================================================================
# Direct release_stage1 / stage2 / stage3
# ===========================================================================


@pytest.mark.asyncio
async def test_release_stage1_direct(db_session, test_event_approved, test_users):
    """Direct release_stage1 sets stage1_released_at and partially_released."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    escrow = await _release_stage1(db_session, test_event_approved.id, pct=30)
    assert escrow.stage1_released_at is not None
    assert escrow.status == EscrowStatus.partially_released
    assert escrow.stage1_released_cents > 0


@pytest.mark.asyncio
async def test_release_stage2_direct(db_session, test_event_approved, test_users):
    """Direct release_stage2 after stage1 sets stage2_released_at."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    await _release_stage1(db_session, test_event_approved.id)
    escrow = await _release_stage2(db_session, test_event_approved.id)
    assert escrow.stage2_released_at is not None
    assert escrow.status == EscrowStatus.partially_released


@pytest.mark.asyncio
async def test_release_stage3_direct(db_session, test_event_approved, test_users):
    """Direct release_stage3 after stage1 + stage2 sets fully_released."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    escrow = await _release_stage3(db_session, test_event_approved.id)
    assert escrow.stage3_released_at is not None
    assert escrow.status == EscrowStatus.fully_released


# ===========================================================================
# freeze / unfreeze
# ===========================================================================


@pytest.mark.asyncio
async def test_freeze_and_unfreeze(db_session, test_event_approved, test_organizer_bank):
    """Freeze sets frozen; unfreeze restores holding."""
    escrow = await te_svc.freeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.frozen
    escrow = await te_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


# ===========================================================================
# list_all
# ===========================================================================


@pytest.mark.asyncio
async def test_list_all(db_session, test_event_approved, test_users):
    """list_all returns escrows with pagination."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.flush()
    items, total = await te_svc.list_all(db_session)
    assert total >= 1
    assert len(items) >= 1
    assert items[0]["event_id"] == test_event_approved.id


# ===========================================================================
# _check_bank_guard
# ===========================================================================


@pytest.mark.asyncio
async def test_bank_guard_with_verified_bank(db_session, test_event_approved, test_organizer_bank):
    """_check_bank_guard returns True when organizer has verified bank."""
    result = await te_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is True


@pytest.mark.asyncio
async def test_bank_guard_without_bank(db_session, test_event_approved, test_users):
    """_check_bank_guard returns False and creates notification when no bank."""
    result = await te_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is False


@pytest.mark.asyncio
async def test_bank_guard_nonexistent_event(db_session, test_users):
    """_check_bank_guard returns False for nonexistent event (no organizer)."""
    result = await te_svc._check_bank_guard(db_session, 999999, stage=1)
    assert result is False


# ===========================================================================
# check_and_release_stage1 — guard checks
# ===========================================================================


@pytest.mark.asyncio
async def test_stage1_auto_event_not_completed(db_session, test_event_approved):
    """Stage1 auto returns None if event is not completed."""
    result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage1_auto_already_released(db_session, test_event_approved, test_users, test_organizer_bank):
    """Stage1 auto returns None if stage1 already released."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()

    # Release stage1 first
    await _release_stage1(db_session, test_event_approved.id)

    # Now auto check should return None (already released)
    result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage1_auto_frozen(db_session, test_event_approved, test_users):
    """Stage1 auto returns None if escrow is frozen."""
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    await te_svc.freeze(db_session, event_id=test_event_approved.id)
    result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage1_auto_disabled(db_session, test_event_approved, test_users):
    """Stage1 auto returns None if auto_release is disabled."""
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.stage1_auto_release = False
    await db_session.flush()
    result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage1_auto_no_end_time(db_session, test_event_approved, test_users):
    """Stage1 auto returns None if event has no end_time."""
    test_event_approved.status = EventStatus.completed
    test_event_approved.end_time = None
    await db_session.flush()

    async def mock_get_int(db_arg, key, **kw):
        return 3

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage1_auto_days_not_elapsed(db_session, test_event_approved, test_users):
    """Stage1 auto returns None if days since end_time < required."""
    test_event_approved.status = EventStatus.completed
    test_event_approved.end_time = datetime.now(timezone.utc) - timedelta(hours=1)
    await db_session.flush()

    async def mock_get_int(db_arg, key, **kw):
        return 3  # Need 3 days, only ~0 days elapsed

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage1_auto_no_bank(db_session, test_event_approved, test_users):
    """Stage1 auto returns None if organizer has no verified bank."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()

    async def mock_get_int(db_arg, key, **kw):
        return 3

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage1_auto_success(db_session, test_event_approved, test_users, test_organizer_bank):
    """Stage1 auto succeeds when all conditions met."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved, days_ago=30)
    await db_session.flush()

    async def mock_get_int(db_arg, key, **kw):
        mapping = {
            "ticket_escrow_stage1_days_after_event": 3,
            "ticket_escrow_stage1_percent": 30,
        }
        return mapping.get(key, 30)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
            result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)

    assert result is not None
    assert result.stage1_released_at is not None
    assert result.status == EscrowStatus.partially_released


# ===========================================================================
# check_and_release_stage2 — guard checks
# ===========================================================================


@pytest.mark.asyncio
async def test_stage2_auto_event_not_completed(db_session, test_event_approved):
    """Stage2 auto returns None if event not completed."""
    result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage2_auto_stage1_not_released(db_session, test_event_approved, test_users):
    """Stage2 auto returns None if stage1 not released."""
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage2_auto_already_released(db_session, test_event_approved, test_users, test_organizer_bank):
    """Stage2 auto returns None if stage2 already released."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)

    result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage2_auto_frozen(db_session, test_event_approved, test_users):
    """Stage2 auto returns None if escrow is frozen."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    await te_svc.freeze(db_session, event_id=test_event_approved.id)

    result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage2_auto_disabled(db_session, test_event_approved, test_users):
    """Stage2 auto returns None if auto_release disabled."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.stage2_auto_release = False
    await db_session.flush()

    result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage2_auto_refund_rate_too_high(db_session, test_event_approved, test_users, test_organizer_bank):
    """Stage2 auto returns None when refund rate exceeds threshold."""
    tier = await _make_tier(db_session, test_event_approved.id)
    # Create 10 purchased and 5 refunded (50% refund rate, > 10% threshold)
    for _ in range(5):
        await _make_ticket_sale(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
            status=TicketSaleStatus.purchased,
        )
    for _ in range(5):
        await _make_ticket_sale(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
            status=TicketSaleStatus.refunded,
        )
    _make_event_completed_with_old_end(test_event_approved, days_ago=30)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)

    async def mock_get_int(db_arg, key, **kw):
        mapping = {
            "ticket_escrow_stage2_days_after_event": 3,
            "ticket_escrow_stage2_max_refund_rate": 10,
            "ticket_escrow_stage2_percent": 40,
        }
        return mapping.get(key, 30)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage2_auto_success(db_session, test_event_approved, test_users, test_organizer_bank):
    """Stage2 auto succeeds with all conditions met and low refund rate."""
    tier = await _make_tier(db_session, test_event_approved.id)
    # 10 purchased, 0 refunded -> 0% refund rate
    for _ in range(10):
        await _make_ticket_sale(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
            status=TicketSaleStatus.purchased,
        )
    _make_event_completed_with_old_end(test_event_approved, days_ago=30)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)

    async def mock_get_int(db_arg, key, **kw):
        mapping = {
            "ticket_escrow_stage2_days_after_event": 3,
            "ticket_escrow_stage2_max_refund_rate": 10,
            "ticket_escrow_stage2_percent": 40,
        }
        return mapping.get(key, 30)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
            result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)

    assert result is not None
    assert result.stage2_released_at is not None


# ===========================================================================
# check_and_release_stage3 — guard checks
# ===========================================================================


@pytest.mark.asyncio
async def test_stage3_auto_event_not_completed(db_session, test_event_approved):
    """Stage3 auto returns None if event not completed."""
    result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage3_auto_stage2_not_released(db_session, test_event_approved, test_users):
    """Stage3 auto returns None if stage2 not released."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    # stage2 not released

    result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage3_auto_already_released(db_session, test_event_approved, test_users, test_organizer_bank):
    """Stage3 auto returns None if stage3 already released."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    await _release_stage3(db_session, test_event_approved.id)

    result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage3_auto_frozen(db_session, test_event_approved, test_users):
    """Stage3 auto returns None if escrow frozen."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    await te_svc.freeze(db_session, event_id=test_event_approved.id)

    result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage3_auto_disabled(db_session, test_event_approved, test_users):
    """Stage3 auto returns None if auto_release disabled."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.stage3_auto_release = False
    await db_session.flush()

    result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage3_auto_open_disputes(db_session, test_event_approved, test_users, test_organizer_bank):
    """Stage3 auto returns None when open disputes exist."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved, days_ago=60)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)

    # Create an open dispute
    dispute = Dispute(
        transaction_id="txn-test-dispute-001",
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        amount_cents=2500,
        status=DisputeStatus.open,
    )
    db_session.add(dispute)
    await db_session.flush()

    async def mock_get_int(db_arg, key, **kw):
        return {"ticket_escrow_stage3_days_after_event": 3, "ticket_escrow_stage3_percent": 30}.get(key, 30)

    async def mock_get_bool(db_arg, key, **kw):
        return {"ticket_escrow_stage3_require_no_disputes": True}.get(key, True)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        with patch.object(te_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
            result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_stage3_auto_success(db_session, test_event_approved, test_users, test_organizer_bank):
    """Stage3 auto succeeds when all conditions met (no disputes)."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved, days_ago=60)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)

    async def mock_get_int(db_arg, key, **kw):
        return {
            "ticket_escrow_stage3_days_after_event": 3,
            "ticket_escrow_stage3_percent": 30,
        }.get(key, 30)

    async def mock_get_bool(db_arg, key, **kw):
        return {"ticket_escrow_stage3_require_no_disputes": True}.get(key, True)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        with patch.object(te_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
            with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)

    assert result is not None
    assert result.stage3_released_at is not None
    assert result.status == EscrowStatus.fully_released


@pytest.mark.asyncio
async def test_stage3_auto_success_disputes_check_disabled(
    db_session, test_event_approved, test_users, test_organizer_bank,
):
    """Stage3 auto succeeds even with open disputes when require_no_disputes is False."""
    tier = await _make_tier(db_session, test_event_approved.id)
    await _make_ticket_sale(
        db_session, event_id=test_event_approved.id,
        user_id=test_users["customer"].id, tier_id=tier.id,
    )
    _make_event_completed_with_old_end(test_event_approved, days_ago=60)
    await db_session.flush()
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)

    # Create an open dispute (should be ignored since check is disabled)
    dispute = Dispute(
        transaction_id="txn-test-dispute-002",
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        amount_cents=2500,
        status=DisputeStatus.open,
    )
    db_session.add(dispute)
    await db_session.flush()

    async def mock_get_int(db_arg, key, **kw):
        return {
            "ticket_escrow_stage3_days_after_event": 3,
            "ticket_escrow_stage3_percent": 30,
        }.get(key, 30)

    async def mock_get_bool(db_arg, key, **kw):
        # Dispute check disabled
        return {"ticket_escrow_stage3_require_no_disputes": False}.get(key, False)

    with patch.object(te_svc.settings_svc, "get_int", side_effect=mock_get_int):
        with patch.object(te_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
            with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)

    assert result is not None
    assert result.stage3_released_at is not None
    assert result.status == EscrowStatus.fully_released
