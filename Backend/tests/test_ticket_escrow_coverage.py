"""
Service-level tests for ticket_escrow.py — get_or_create, release stages,
freeze, unfreeze, list_all, auto-trigger check_and_release_stage1/2/3.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.escrow import TicketEscrow, EscrowStatus
from app.models.event import Event, EventStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
from app.core.exceptions import ConflictError

from app.services import ticket_escrow as te_svc


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

async def _make_ticket_sale(db, event, user, amount_cents=5000):
    """Create a tier + ticket sale."""
    tier = TicketTier(event_id=event.id, name="GA", price_cents=amount_cents, display_order=0)
    db.add(tier)
    await db.flush()
    sale = TicketSale(
        event_id=event.id, user_id=user.id, ticket_tier_id=tier.id,
        ticket_code="TKT-TE-TEST", receipt_number="TKT-TE-REC",
        amount_paid_cents=amount_cents, commission_cents=amount_cents * 10 // 100,
        status=TicketSaleStatus.purchased,
    )
    db.add(sale)
    await db.flush()
    return sale


# ===========================================================================
# get_or_create, refresh_total
# ===========================================================================

@pytest.mark.asyncio
async def test_get_or_create(db_session, test_event_approved):
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow is not None
    assert escrow.event_id == test_event_approved.id


@pytest.mark.asyncio
async def test_get_or_create_idempotent(db_session, test_event_approved):
    e1 = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    e2 = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert e1.id == e2.id


@pytest.mark.asyncio
async def test_refresh_total_with_sale(db_session, test_event_approved, test_users):
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"], 5000)
    escrow = await te_svc.refresh_total(db_session, test_event_approved.id)
    assert escrow.total_held_cents == 4500  # 5000 - 10% commission


@pytest.mark.asyncio
async def test_refresh_total_empty(db_session, test_event_approved):
    escrow = await te_svc.refresh_total(db_session, test_event_approved.id)
    assert escrow.total_held_cents == 0


# ===========================================================================
# freeze / unfreeze / reject
# ===========================================================================

@pytest.mark.asyncio
async def test_freeze(db_session, test_event_approved):
    escrow = await te_svc.freeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.frozen


@pytest.mark.asyncio
async def test_unfreeze(db_session, test_event_approved, test_organizer_bank):
    await te_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await te_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_release_frozen_fails(db_session, test_event_approved):
    await te_svc.freeze(db_session, event_id=test_event_approved.id)
    with pytest.raises(ConflictError, match="frozen"):
        await te_svc.release_stage1(db_session, event_id=test_event_approved.id)


@pytest.mark.asyncio
async def test_reject_if_refunded(db_session, test_event_approved):
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    escrow.status = EscrowStatus.refunded
    await db_session.flush()
    with pytest.raises(ConflictError, match="refunded"):
        te_svc._reject_if_blocked(escrow)


# ===========================================================================
# release stages
# ===========================================================================

@pytest.mark.asyncio
async def test_release_stage1(db_session, test_event_approved, test_users, test_organizer_bank):
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"])
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        escrow = await te_svc.release_stage1(db_session, event_id=test_event_approved.id)
    assert escrow.stage1_released_at is not None
    assert escrow.status == EscrowStatus.partially_released


@pytest.mark.asyncio
async def test_release_stage1_duplicate(db_session, test_event_approved, test_users, test_organizer_bank):
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"])
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        await te_svc.release_stage1(db_session, event_id=test_event_approved.id)
        with pytest.raises(ConflictError, match="already released"):
            await te_svc.release_stage1(db_session, event_id=test_event_approved.id)


@pytest.mark.asyncio
async def test_release_stage2_requires_stage1(db_session, test_event_approved, test_users):
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"])
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        with pytest.raises(ConflictError, match="Stage 1"):
            await te_svc.release_stage2(db_session, event_id=test_event_approved.id)


@pytest.mark.asyncio
async def test_release_all_three_stages(db_session, test_event_approved, test_users, test_organizer_bank):
    """Full three-stage release flow."""
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"])
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        await te_svc.release_stage1(db_session, event_id=test_event_approved.id)
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        await te_svc.release_stage2(db_session, event_id=test_event_approved.id)
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=40):
        escrow = await te_svc.release_stage3(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.fully_released


# ===========================================================================
# list_all
# ===========================================================================

@pytest.mark.asyncio
async def test_list_all(db_session, test_event_approved):
    await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.flush()
    items, total = await te_svc.list_all(db_session)
    assert total >= 1


# ===========================================================================
# check_and_release_stage1 (auto-trigger)
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage1_not_completed(db_session, test_event_approved):
    """Auto-trigger returns None when event not completed."""
    result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_no_event(db_session):
    """Auto-trigger returns None for non-existent event."""
    result = await te_svc.check_and_release_stage1(db_session, event_id=99999)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_already_released(db_session, test_event_completed, test_users, test_organizer_bank):
    """Auto-trigger returns None when already released."""
    await _make_ticket_sale(db_session, test_event_completed, test_users["customer"])
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
        await te_svc.release_stage1(db_session, event_id=test_event_completed.id)
    result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_completed.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_auto_release_disabled(db_session, test_event_completed, test_users):
    """Auto-trigger returns None when auto_release flag is off."""
    await _make_ticket_sale(db_session, test_event_completed, test_users["customer"])
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_completed.id)
    escrow.stage1_auto_release = False
    await db_session.flush()
    result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_completed.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_too_early(db_session, test_event_completed, test_users):
    """Auto-trigger returns None when grace period not elapsed."""
    await _make_ticket_sale(db_session, test_event_completed, test_users["customer"])
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_completed.id)
    escrow.stage1_auto_release = True
    # Set end_time to now so days_since < days_required
    test_event_completed.end_time = datetime.now(timezone.utc)
    await db_session.flush()
    with patch.object(te_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=30):
        result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_completed.id)
    assert result is None  # not enough days


@pytest.mark.asyncio
async def test_auto_stage1_fires(db_session, test_event_completed, test_users, test_organizer_bank):
    """Auto-trigger fires when all conditions met."""
    await _make_ticket_sale(db_session, test_event_completed, test_users["customer"])
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_completed.id)
    escrow.stage1_auto_release = True
    # Set end_time to 60 days ago
    test_event_completed.end_time = datetime.now(timezone.utc) - timedelta(days=60)
    await db_session.flush()
    with patch.object(te_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=7):
        with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
            with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_completed.id)
    assert result is not None
    assert result.stage1_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage1_no_end_time(db_session, test_event_completed, test_users):
    """Auto-trigger returns None when event has no end_time."""
    await _make_ticket_sale(db_session, test_event_completed, test_users["customer"])
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_completed.id)
    escrow.stage1_auto_release = True
    test_event_completed.end_time = None
    await db_session.flush()
    with patch.object(te_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=7):
        result = await te_svc.check_and_release_stage1(db_session, event_id=test_event_completed.id)
    assert result is None


# ===========================================================================
# check_and_release_stage2 (auto-trigger)
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage2_not_completed(db_session, test_event_approved):
    """Stage 2 auto-trigger returns None when event not completed."""
    result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage2_no_stage1(db_session, test_event_completed, test_users):
    """Stage 2 auto-trigger returns None when stage 1 not released."""
    await _make_ticket_sale(db_session, test_event_completed, test_users["customer"])
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_completed.id)
    escrow.stage2_auto_release = True
    await db_session.flush()
    result = await te_svc.check_and_release_stage2(db_session, event_id=test_event_completed.id)
    assert result is None


# ===========================================================================
# check_and_release_stage3 (auto-trigger)
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage3_not_completed(db_session, test_event_approved):
    """Stage 3 auto-trigger returns None when event not completed."""
    result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_no_stage2(db_session, test_event_completed, test_users):
    """Stage 3 auto-trigger returns None when stage 2 not released."""
    await _make_ticket_sale(db_session, test_event_completed, test_users["customer"])
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_completed.id)
    escrow.stage3_auto_release = True
    await db_session.flush()
    result = await te_svc.check_and_release_stage3(db_session, event_id=test_event_completed.id)
    assert result is None


# ===========================================================================
# _check_bank_guard
# ===========================================================================

@pytest.mark.asyncio
async def test_bank_guard_no_bank(db_session, test_event_approved):
    result = await te_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is False


@pytest.mark.asyncio
async def test_bank_guard_with_bank(db_session, test_event_approved, test_organizer_bank):
    result = await te_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is True


@pytest.mark.asyncio
async def test_bank_guard_no_event(db_session):
    result = await te_svc._check_bank_guard(db_session, 99999, stage=1)
    assert result is False
