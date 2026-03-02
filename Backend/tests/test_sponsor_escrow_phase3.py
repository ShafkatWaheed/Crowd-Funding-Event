"""
Service-level tests for sponsor_escrow.py — Phase 3.
Covers auto-trigger functions: check_and_release_stage1/2/3,
_check_bank_guard, get_or_create, refresh_total, release stages,
freeze/unfreeze, and all trigger modes with guard conditions.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.core.exceptions import ConflictError
from app.models.escrow import SponsorEscrow, EscrowStatus
from app.models.event import Event, EventStatus
from app.models.sponsor import (
    SponsorBid, SponsorPayment, SponsorshipCategory, BidStatus, PaymentStatus,
)
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier

import app.services.sponsor_escrow as se_svc


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

_payment_counter = 0


async def _make_sponsor_payment(db, event, sponsor_user, amount_cents=10000):
    """Create category + bid + payment so the escrow has funds to hold."""
    global _payment_counter
    _payment_counter += 1
    cat = SponsorshipCategory(
        event_id=event.id, name=f"Gold-{_payment_counter}",
        total_spots=3, min_bid_cents=5000,
    )
    db.add(cat)
    await db.flush()
    bid = SponsorBid(
        category_id=cat.id, sponsor_user_id=sponsor_user.id,
        amount_cents=amount_cents, proposal_text="Test", status=BidStatus.paid,
    )
    db.add(bid)
    await db.flush()
    platform_cut = amount_cents * 10 // 100
    payment = SponsorPayment(
        bid_id=bid.id, amount_cents=amount_cents,
        platform_cut_cents=platform_cut,
        net_to_organizer_cents=amount_cents - platform_cut,
        receipt_number=f"SP-P3-{bid.id}-{_payment_counter}",
        status=PaymentStatus.completed,
    )
    db.add(payment)
    await db.flush()
    return payment


_ticket_counter = 0


async def _make_ticket_sale(db, event, user, amount_cents=3000):
    """Create a ticket tier + purchased sale for ticket_percent calculations."""
    global _ticket_counter
    _ticket_counter += 1
    tier = TicketTier(
        event_id=event.id, name=f"GA-SE-{_ticket_counter}",
        price_cents=amount_cents, display_order=0,
    )
    db.add(tier)
    await db.flush()
    sale = TicketSale(
        event_id=event.id, user_id=user.id, ticket_tier_id=tier.id,
        ticket_code=f"TKC-SE-{event.id}-{_ticket_counter}",
        amount_paid_cents=amount_cents,
        status=TicketSaleStatus.purchased,
        receipt_number=f"TK-SE-{event.id}-{_ticket_counter}",
    )
    db.add(sale)
    await db.flush()
    return sale


async def _release_stage(db, event_id, stage, pct=30):
    """Release a specific stage with mocked settings for test setup."""
    async def mock_get_int(db, key, **kw):
        return pct

    fn = {
        1: se_svc.release_stage1,
        2: se_svc.release_stage2,
        3: se_svc.release_stage3,
    }[stage]
    with patch.object(se_svc.settings_svc, "get_int", side_effect=mock_get_int):
        return await fn(db, event_id=event_id)


# ===========================================================================
# get_or_create
# ===========================================================================

@pytest.mark.asyncio
async def test_get_or_create_new(db_session, test_event_approved):
    """Creates a new SponsorEscrow for an event."""
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow is not None
    assert escrow.event_id == test_event_approved.id
    assert escrow.status == EscrowStatus.holding
    assert escrow.total_held_cents == 0


@pytest.mark.asyncio
async def test_get_or_create_idempotent(db_session, test_event_approved):
    """Second call returns the same escrow record (idempotent)."""
    e1 = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    e2 = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert e1.id == e2.id


# ===========================================================================
# refresh_total
# ===========================================================================

@pytest.mark.asyncio
async def test_refresh_total_updates_from_payments(db_session, test_event_approved, test_users_with_sponsor):
    """After adding payments, refresh_total updates total_held_cents."""
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow.total_held_cents == 0

    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"], 20000,
    )
    updated = await se_svc.refresh_total(db_session, test_event_approved.id)
    # net_to_organizer = 20000 - 10% = 18000
    assert updated.total_held_cents == 18000


# ===========================================================================
# release_stage1 / 2 / 3
# ===========================================================================

@pytest.mark.asyncio
async def test_release_stage1_success(db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank):
    """Stage 1 release calculates correct amount."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"], 20000,
    )
    escrow = await _release_stage(db_session, test_event_approved.id, 1, pct=30)
    assert escrow.stage1_released_at is not None
    assert escrow.status == EscrowStatus.partially_released
    assert escrow.stage1_released_cents == 18000 * 30 // 100  # 5400


@pytest.mark.asyncio
async def test_release_stage2_requires_stage1(db_session, test_event_approved, test_users_with_sponsor):
    """Cannot release stage 2 before stage 1."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    with pytest.raises(ConflictError, match="Stage 1 must be released"):
        await _release_stage(db_session, test_event_approved.id, 2)


@pytest.mark.asyncio
async def test_release_stage3_fully_released(db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank):
    """Full three-stage release flow ends with fully_released."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"], 30000,
    )
    await _release_stage(db_session, test_event_approved.id, 1, pct=30)
    await _release_stage(db_session, test_event_approved.id, 2, pct=40)
    escrow = await _release_stage(db_session, test_event_approved.id, 3, pct=30)
    assert escrow.stage3_released_at is not None
    assert escrow.status == EscrowStatus.fully_released


@pytest.mark.asyncio
async def test_release_frozen_fails(db_session, test_event_approved, test_users_with_sponsor):
    """Cannot release stage on a frozen escrow."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await se_svc.freeze(db_session, event_id=test_event_approved.id)
    with pytest.raises(ConflictError, match="frozen"):
        await _release_stage(db_session, test_event_approved.id, 1)


# ===========================================================================
# freeze / unfreeze
# ===========================================================================

@pytest.mark.asyncio
async def test_freeze_sets_frozen(db_session, test_event_approved):
    """Freeze sets escrow status to frozen."""
    escrow = await se_svc.freeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.frozen


@pytest.mark.asyncio
async def test_unfreeze_restores_holding(db_session, test_event_approved, test_organizer_bank):
    """Unfreeze restores status to holding when no stages released."""
    await se_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await se_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_unfreeze_restores_partially_released(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """Unfreeze after stage 1 restores to partially_released."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)
    await se_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await se_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.partially_released


# ===========================================================================
# check_and_release_stage1 — guards
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage1_trigger_disabled(db_session, test_event_approved):
    """Returns None when trigger is disabled."""
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_event_not_found(db_session):
    """Returns None for non-existent event."""
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage1(db_session, event_id=99999)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_already_released(db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank):
    """Returns None if stage 1 already released."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)

    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_frozen_skips(db_session, test_event_approved, test_users_with_sponsor):
    """Returns None if escrow is frozen."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await se_svc.freeze(db_session, event_id=test_event_approved.id)

    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_auto_release_disabled(db_session, test_event_approved, test_users_with_sponsor):
    """Returns None if stage1_auto_release is False."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    escrow = await se_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.stage1_auto_release = False
    await db_session.flush()

    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_unknown_mode(db_session, test_event_approved, test_users_with_sponsor):
    """Returns None for unknown trigger mode."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )

    async def mock_get_bool(db, key, **kw):
        return True

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="unknown_mode"):
            result = await se_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


# ===========================================================================
# check_and_release_stage1 — event_live mode
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage1_event_live_fires(db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank):
    """event_live mode releases when event status is live."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    test_event_approved.status = EventStatus.live
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "event_live"

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=30):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await se_svc.check_and_release_stage1(
                        db_session, event_id=test_event_approved.id,
                    )
    assert result is not None
    assert result.stage1_released_at is not None
    assert result.status == EscrowStatus.partially_released


@pytest.mark.asyncio
async def test_auto_stage1_event_live_not_live_yet(db_session, test_event_approved, test_users_with_sponsor):
    """event_live mode returns None when event is not yet live."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    # event status remains 'approved'

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "event_live"

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            result = await se_svc.check_and_release_stage1(
                db_session, event_id=test_event_approved.id,
            )
    assert result is None


# ===========================================================================
# check_and_release_stage1 — days_before_event mode
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage1_days_before_event_fires(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """days_before_event mode releases when within N days of start."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    # Start time is 2 days away; setting says trigger at 5 days before
    test_event_approved.start_time = datetime.now(timezone.utc) + timedelta(days=2)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "days_before_event"

    async def mock_get_int(db, key, **kw):
        if key == "sponsor_escrow_stage1_days_before_event":
            return 5
        return 30  # stage percent

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", side_effect=mock_get_int):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await se_svc.check_and_release_stage1(
                        db_session, event_id=test_event_approved.id,
                    )
    assert result is not None
    assert result.stage1_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage1_days_before_event_too_far(
    db_session, test_event_approved, test_users_with_sponsor,
):
    """days_before_event mode returns None when start_time is too far away."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    # Start time is 30 days away; setting says trigger at 5 days before
    test_event_approved.start_time = datetime.now(timezone.utc) + timedelta(days=30)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "days_before_event"

    async def mock_get_int(db, key, **kw):
        if key == "sponsor_escrow_stage1_days_before_event":
            return 5
        return 30

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", side_effect=mock_get_int):
                result = await se_svc.check_and_release_stage1(
                    db_session, event_id=test_event_approved.id,
                )
    assert result is None


# ===========================================================================
# check_and_release_stage2 — guards
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage2_trigger_disabled(db_session, test_event_approved):
    """Returns None when stage 2 trigger is disabled."""
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await se_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage2_stage1_not_released(db_session, test_event_approved, test_users_with_sponsor):
    """Returns None when stage 1 has not been released yet."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )

    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


# ===========================================================================
# check_and_release_stage2 — event_started mode
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage2_event_started_fires(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """event_started mode releases when past start_time."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)
    test_event_approved.start_time = datetime.now(timezone.utc) - timedelta(hours=1)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "event_started"

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=40):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await se_svc.check_and_release_stage2(
                        db_session, event_id=test_event_approved.id,
                    )
    assert result is not None
    assert result.stage2_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage2_event_started_future(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """event_started mode returns None when start_time is in the future."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)
    test_event_approved.start_time = datetime.now(timezone.utc) + timedelta(days=7)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "event_started"

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            result = await se_svc.check_and_release_stage2(
                db_session, event_id=test_event_approved.id,
            )
    assert result is None


# ===========================================================================
# check_and_release_stage2 — ticket_percent mode
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage2_ticket_percent_fires(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """ticket_percent mode releases when enough tickets sold."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)

    # max_capacity = 2, sell 1 ticket => 50% sold
    test_event_approved.max_capacity = 2
    await db_session.flush()
    await _make_ticket_sale(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "ticket_percent"

    async def mock_get_int(db, key, **kw):
        if key == "sponsor_escrow_stage2_ticket_percent":
            return 50
        return 40  # stage percent

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", side_effect=mock_get_int):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await se_svc.check_and_release_stage2(
                        db_session, event_id=test_event_approved.id,
                    )
    assert result is not None
    assert result.stage2_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage2_ticket_percent_below_threshold(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """ticket_percent mode returns None when below threshold."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)

    # max_capacity = 100, no tickets sold => 0%
    test_event_approved.max_capacity = 100
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "ticket_percent"

    async def mock_get_int(db, key, **kw):
        if key == "sponsor_escrow_stage2_ticket_percent":
            return 50
        return 40

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", side_effect=mock_get_int):
                result = await se_svc.check_and_release_stage2(
                    db_session, event_id=test_event_approved.id,
                )
    assert result is None


# ===========================================================================
# check_and_release_stage3 — guards
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage3_trigger_disabled(db_session, test_event_approved):
    """Returns None when stage 3 trigger is disabled."""
    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await se_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_stage2_not_released(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """Returns None when stage 2 has not been released yet."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)

    with patch.object(se_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await se_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


# ===========================================================================
# check_and_release_stage3 — days_after_event mode
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage3_days_after_event_fires(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """days_after_event mode releases when enough days have passed since end_time."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)
    await _release_stage(db_session, test_event_approved.id, 2)

    test_event_approved.end_time = datetime.now(timezone.utc) - timedelta(days=30)
    test_event_approved.status = EventStatus.completed
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "days_after_event"

    async def mock_get_int(db, key, **kw):
        if key == "sponsor_escrow_stage3_days_after_event":
            return 14
        return 30  # stage percent

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", side_effect=mock_get_int):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await se_svc.check_and_release_stage3(
                        db_session, event_id=test_event_approved.id,
                    )
    assert result is not None
    assert result.stage3_released_at is not None
    assert result.status == EscrowStatus.fully_released


@pytest.mark.asyncio
async def test_auto_stage3_days_after_event_not_enough(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """days_after_event mode returns None when not enough days have passed."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)
    await _release_stage(db_session, test_event_approved.id, 2)

    # Only 2 days since end, threshold is 14
    test_event_approved.end_time = datetime.now(timezone.utc) - timedelta(days=2)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "days_after_event"

    async def mock_get_int(db, key, **kw):
        if key == "sponsor_escrow_stage3_days_after_event":
            return 14
        return 30

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", side_effect=mock_get_int):
                result = await se_svc.check_and_release_stage3(
                    db_session, event_id=test_event_approved.id,
                )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_days_after_event_no_end_time(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """days_after_event mode returns None when event has no end_time."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)
    await _release_stage(db_session, test_event_approved.id, 2)

    test_event_approved.end_time = None
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "days_after_event"

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            result = await se_svc.check_and_release_stage3(
                db_session, event_id=test_event_approved.id,
            )
    assert result is None


# ===========================================================================
# check_and_release_stage3 — sponsor_confirmed mode
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage3_sponsor_confirmed_fires(
    db_session, test_event_approved, test_users_with_sponsor, test_organizer_bank,
):
    """sponsor_confirmed mode always passes the condition check (manual trigger)."""
    await _make_sponsor_payment(
        db_session, test_event_approved, test_users_with_sponsor["sponsor"],
    )
    await _release_stage(db_session, test_event_approved.id, 1)
    await _release_stage(db_session, test_event_approved.id, 2)

    async def mock_get_bool(db, key, **kw):
        return True

    async def mock_get_str(db, key, **kw):
        return "sponsor_confirmed"

    with patch.object(se_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(se_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(se_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=30):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await se_svc.check_and_release_stage3(
                        db_session, event_id=test_event_approved.id,
                    )
    assert result is not None
    assert result.stage3_released_at is not None
    assert result.status == EscrowStatus.fully_released


# ===========================================================================
# _check_bank_guard
# ===========================================================================

@pytest.mark.asyncio
async def test_bank_guard_with_verified_bank(db_session, test_event_approved, test_organizer_bank):
    """Returns True when organizer has a verified bank account."""
    result = await se_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is True


@pytest.mark.asyncio
async def test_bank_guard_no_bank_creates_notification(db_session, test_event_approved, test_users):
    """Returns False and creates notification when no verified bank."""
    with patch("app.services.notification_service.create_notification", new_callable=AsyncMock) as mock_notif:
        result = await se_svc._check_bank_guard(db_session, test_event_approved.id, stage=2)
    assert result is False
    mock_notif.assert_called_once()
    call_kwargs = mock_notif.call_args
    assert "stage" in str(call_kwargs)


@pytest.mark.asyncio
async def test_bank_guard_nonexistent_event(db_session):
    """Returns False for non-existent event (no organizer found)."""
    result = await se_svc._check_bank_guard(db_session, 99999, stage=1)
    assert result is False
