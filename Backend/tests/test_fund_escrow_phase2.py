"""
Service-level tests for escrow.py (fund escrow) — Phase 2.
Covers: get_or_create, refresh_total, _reject_if_blocked, _mark_waived,
release_stage1 (trust score), release_stage2/3, freeze, unfreeze (custom),
get_escrow_summary, check_and_release_stage1/2/3, _check_bank_guard,
_check_community_waiver, list_all_escrows.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.core.exceptions import ConflictError
from app.models.escrow import EscrowStatus, FundEscrow
from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
from app.models.user import User

from app.services import escrow as escrow_svc


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

async def _make_pledge(db, event, user, amount_cents=5000):
    p = Funding(
        event_id=event.id, user_id=user.id,
        amount_cents=amount_cents,
        platform_cut_cents=amount_cents * 10 // 100,
        net_to_organizer_cents=amount_cents - amount_cents * 10 // 100,
        status=FundingStatus.pledged,
        receipt_number=f"PLG-{event.id}-{user.id}",
    )
    db.add(p)
    await db.flush()
    return p


_ticket_counter = 0

async def _make_ticket_sale(db, event, user, amount_cents=3000, scanned=False):
    global _ticket_counter
    _ticket_counter += 1
    tier = TicketTier(event_id=event.id, name=f"GA-{_ticket_counter}", price_cents=amount_cents, display_order=0)
    db.add(tier)
    await db.flush()
    commission = amount_cents * 10 // 100
    sale = TicketSale(
        event_id=event.id,
        user_id=user.id,
        ticket_tier_id=tier.id,
        ticket_code=f"TKC-{event.id}-{user.id}-{_ticket_counter}",
        amount_paid_cents=amount_cents,
        commission_cents=commission,
        net_to_organizer_cents=amount_cents - commission,
        status=TicketSaleStatus.purchased,
        receipt_number=f"TK-{event.id}-{user.id}-{_ticket_counter}",
        gateway_transaction_id=f"txn-tk-{event.id}-{user.id}-{_ticket_counter}",
    )
    if scanned:
        sale.scanned_at = datetime.now(timezone.utc)
    db.add(sale)
    await db.flush()
    return sale


def _trust_patch(score=0.5):
    """Return a patch for get_organizer_trust_score."""
    return patch(
        "app.services.event.get_organizer_trust_score",
        new_callable=AsyncMock, return_value={"trust_score": score},
    )


def _settings_int_patch(value=30):
    """Patch escrow_svc.settings_svc.get_int."""
    return patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=value)


async def _release_stage1(db, event_id, pct=30, trust=0.5):
    """Helper to release stage 1 with standard mocks. Trust threshold set high to avoid boost."""

    async def mock_get_int(db, key, **kw):
        if key == "escrow_stage1_percent":
            return pct
        if key == "escrow_trust_score_threshold":
            return 99  # high threshold so trust boost doesn't fire
        return 0

    with patch.object(escrow_svc.settings_svc, "get_int", side_effect=mock_get_int):
        with _trust_patch(trust):
            return await escrow_svc.release_stage1(db, event_id=event_id)


async def _release_stage2(db, event_id, pct=40):
    """Helper to release stage 2."""
    with _settings_int_patch(pct):
        return await escrow_svc.release_stage2(db, event_id=event_id)


# ===========================================================================
# get_or_create
# ===========================================================================

@pytest.mark.asyncio
async def test_get_or_create_new(db_session, test_event_approved):
    """Create new fund escrow."""
    escrow = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow is not None
    assert escrow.event_id == test_event_approved.id
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_get_or_create_idempotent(db_session, test_event_approved):
    """get_or_create returns same record on second call."""
    e1 = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    e2 = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert e1.id == e2.id


@pytest.mark.asyncio
async def test_get_or_create_with_pledges(db_session, test_event_approved, test_users):
    """Escrow total_held_cents reflects pledged fundings."""
    customer = test_users["customer"]
    await _make_pledge(db_session, test_event_approved, customer, 10000)
    escrow = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow.total_held_cents == 9000  # 10000 - 10% platform cut


# ===========================================================================
# refresh_total
# ===========================================================================

@pytest.mark.asyncio
async def test_refresh_total(db_session, test_event_approved, test_users):
    """refresh_total recalculates from current pledges."""
    escrow = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow.total_held_cents == 0
    await _make_pledge(db_session, test_event_approved, test_users["customer"], 6000)
    updated = await escrow_svc.refresh_total(db_session, escrow)
    assert updated.total_held_cents == 5400  # 6000 - 10%


# ===========================================================================
# _reject_if_blocked
# ===========================================================================

def test_reject_if_frozen():
    """Frozen escrow raises ConflictError."""
    esc = FundEscrow()
    esc.status = EscrowStatus.frozen
    with pytest.raises(ConflictError, match="frozen"):
        escrow_svc._reject_if_blocked(esc)


def test_reject_if_waived():
    """Waived escrow raises ConflictError."""
    esc = FundEscrow()
    esc.status = EscrowStatus.waived
    with pytest.raises(ConflictError, match="waived"):
        escrow_svc._reject_if_blocked(esc)


def test_reject_if_blocked_holding_ok():
    """Holding escrow does not raise."""
    esc = FundEscrow()
    esc.status = EscrowStatus.holding
    escrow_svc._reject_if_blocked(esc)  # no exception


# ===========================================================================
# _mark_waived
# ===========================================================================

@pytest.mark.asyncio
async def test_mark_waived(db_session, test_event_approved):
    """_mark_waived sets escrow to waived status."""
    escrow = await escrow_svc._mark_waived(db_session, test_event_approved.id)
    assert escrow.status == EscrowStatus.waived


@pytest.mark.asyncio
async def test_mark_waived_idempotent(db_session, test_event_approved):
    """Calling _mark_waived twice returns same escrow."""
    e1 = await escrow_svc._mark_waived(db_session, test_event_approved.id)
    e2 = await escrow_svc._mark_waived(db_session, test_event_approved.id)
    assert e1.id == e2.id
    assert e2.status == EscrowStatus.waived


# ===========================================================================
# release_stage1 — with trust score logic
# ===========================================================================

@pytest.mark.asyncio
async def test_release_stage1_basic(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Stage 1 release at 30%."""
    escrow = await _release_stage1(db_session, test_event_approved.id, pct=30, trust=0.5)
    assert escrow.stage1_released_at is not None
    assert escrow.status == EscrowStatus.partially_released
    # pledge is 1800 net; 30% = 540
    assert escrow.stage1_released_cents == 1800 * 30 // 100


@pytest.mark.asyncio
async def test_release_stage1_trust_boost(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """High trust score + pct<40 → boosted to 40%."""

    async def mock_get_int(db, key, **kw):
        if key == "escrow_stage1_percent":
            return 30
        if key == "escrow_trust_score_threshold":
            return 80  # threshold = 0.80
        return 0

    with patch.object(escrow_svc.settings_svc, "get_int", side_effect=mock_get_int):
        with _trust_patch(0.9):
            escrow = await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)
    # trust 0.9 > threshold 0.8, and pct=30 < 40, so pct boosted to 40
    assert escrow.stage1_released_cents == 1800 * 40 // 100


@pytest.mark.asyncio
async def test_release_stage1_already_released(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Cannot release stage 1 twice."""
    await _release_stage1(db_session, test_event_approved.id)
    with pytest.raises(ConflictError, match="Stage 1 already released"):
        await _release_stage1(db_session, test_event_approved.id)


@pytest.mark.asyncio
async def test_release_stage1_frozen_blocked(db_session, test_event_approved, test_pledge):
    """Cannot release stage 1 on frozen escrow."""
    await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    with pytest.raises(ConflictError, match="frozen"):
        await _release_stage1(db_session, test_event_approved.id)


# ===========================================================================
# release_stage2
# ===========================================================================

@pytest.mark.asyncio
async def test_release_stage2_success(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Stage 2 release after stage 1."""
    await _release_stage1(db_session, test_event_approved.id)
    escrow = await _release_stage2(db_session, test_event_approved.id, pct=40)
    assert escrow.stage2_released_at is not None
    assert escrow.stage2_released_cents == 1800 * 40 // 100


@pytest.mark.asyncio
async def test_release_stage2_requires_stage1(db_session, test_event_approved, test_pledge):
    """Cannot release stage 2 without stage 1."""
    with pytest.raises(ConflictError, match="Stage 1 must be released"):
        await _release_stage2(db_session, test_event_approved.id)


# ===========================================================================
# release_stage3
# ===========================================================================

@pytest.mark.asyncio
async def test_release_stage3_success(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Full three-stage release flow."""
    await _release_stage1(db_session, test_event_approved.id, pct=30)
    await _release_stage2(db_session, test_event_approved.id, pct=40)
    with _settings_int_patch(30):
        escrow = await escrow_svc.release_stage3(db_session, event_id=test_event_approved.id)
    assert escrow.stage3_released_at is not None
    assert escrow.status == EscrowStatus.fully_released


@pytest.mark.asyncio
async def test_release_stage3_requires_stage2(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Cannot release stage 3 before stage 2."""
    await _release_stage1(db_session, test_event_approved.id)
    with pytest.raises(ConflictError, match="Stage 2 must be released"):
        with _settings_int_patch(30):
            await escrow_svc.release_stage3(db_session, event_id=test_event_approved.id)


# ===========================================================================
# freeze / unfreeze (custom)
# ===========================================================================

@pytest.mark.asyncio
async def test_freeze(db_session, test_event_approved):
    """Freeze fund escrow."""
    escrow = await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.frozen


@pytest.mark.asyncio
async def test_unfreeze_to_holding(db_session, test_event_approved, test_organizer_bank):
    """Unfreeze with no releases → holding."""
    await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await escrow_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_unfreeze_to_partially_released(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Unfreeze after stage 1 → partially_released."""
    await _release_stage1(db_session, test_event_approved.id)
    await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await escrow_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.partially_released


@pytest.mark.asyncio
async def test_unfreeze_to_fully_released(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Unfreeze after all 3 stages → fully_released."""
    await _release_stage1(db_session, test_event_approved.id, pct=30)
    await _release_stage2(db_session, test_event_approved.id, pct=40)
    with _settings_int_patch(30):
        await escrow_svc.release_stage3(db_session, event_id=test_event_approved.id)
    await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await escrow_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.fully_released


@pytest.mark.asyncio
async def test_unfreeze_waived(db_session, test_event_approved, test_organizer_bank):
    """Unfreeze a waived escrow → holding."""
    await escrow_svc._mark_waived(db_session, test_event_approved.id)
    escrow = await escrow_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_unfreeze_not_frozen_fails(db_session, test_event_approved):
    """Unfreeze a holding escrow raises ConflictError."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    with pytest.raises(ConflictError, match="not frozen or waived"):
        await escrow_svc.unfreeze(db_session, event_id=test_event_approved.id)


# ===========================================================================
# get_escrow_summary
# ===========================================================================

@pytest.mark.asyncio
async def test_get_escrow_summary_empty(db_session, test_event_approved):
    """Summary for new escrow shows zeros."""
    summary = await escrow_svc.get_escrow_summary(db_session, event_id=test_event_approved.id)
    assert summary["event_id"] == test_event_approved.id
    assert summary["total_held_cents"] == 0
    assert summary["stage1_released_cents"] == 0
    assert summary["stage1_released_at"] is None
    assert summary["remaining_cents"] == 0
    assert summary["status"] == "holding"


@pytest.mark.asyncio
async def test_get_escrow_summary_after_release(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Summary after stage 1 release shows correct breakdown."""
    await _release_stage1(db_session, test_event_approved.id, pct=30)
    summary = await escrow_svc.get_escrow_summary(db_session, event_id=test_event_approved.id)
    assert summary["stage1_released_cents"] == 1800 * 30 // 100
    assert summary["stage1_released_at"] is not None
    assert summary["total_released_cents"] == 1800 * 30 // 100
    assert summary["remaining_cents"] == 1800 - 1800 * 30 // 100
    assert summary["status"] == "partially_released"


# ===========================================================================
# list_all_escrows
# ===========================================================================

@pytest.mark.asyncio
async def test_list_all_escrows(db_session, test_event_approved):
    """List fund escrows."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    items, total = await escrow_svc.list_all_escrows(db_session)
    assert total >= 1


# ===========================================================================
# _check_community_waiver
# ===========================================================================

@pytest.mark.asyncio
async def test_check_community_waiver_disabled(db_session, test_event_approved):
    """No waiver when community_escrow_disabled is False."""
    test_event_approved.community_rules = True
    await db_session.flush()
    with patch.object(escrow_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await escrow_svc._check_community_waiver(db_session, test_event_approved)
    assert result is None


@pytest.mark.asyncio
async def test_check_community_waiver_enabled(db_session, test_event_approved):
    """Waiver granted when community_rules=True and setting is enabled."""
    test_event_approved.community_rules = True
    await db_session.flush()
    with patch.object(escrow_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await escrow_svc._check_community_waiver(db_session, test_event_approved)
    assert result is not None
    assert result.status == EscrowStatus.waived


@pytest.mark.asyncio
async def test_check_community_waiver_no_community_rules(db_session, test_event_approved):
    """No waiver when event has no community_rules."""
    test_event_approved.community_rules = False
    await db_session.flush()
    with patch.object(escrow_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await escrow_svc._check_community_waiver(db_session, test_event_approved)
    assert result is None


# ===========================================================================
# _check_bank_guard
# ===========================================================================

@pytest.mark.asyncio
async def test_check_bank_guard_with_bank(db_session, test_event_approved, test_organizer_bank):
    """Bank guard passes when organizer has verified bank."""
    result = await escrow_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is True


@pytest.mark.asyncio
async def test_check_bank_guard_no_bank(db_session, test_event_approved, test_users):
    """Bank guard fails and sends notification when no verified bank."""
    with patch("app.services.notification_service.create_notification", new_callable=AsyncMock):
        result = await escrow_svc._check_bank_guard(db_session, test_event_approved.id, stage=1)
    assert result is False


@pytest.mark.asyncio
async def test_check_bank_guard_no_event(db_session):
    """Bank guard returns False for non-existent event."""
    result = await escrow_svc._check_bank_guard(db_session, 99999, stage=1)
    assert result is False


# ===========================================================================
# check_and_release_stage1
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage1_disabled(db_session, test_event_approved):
    """Auto stage 1 returns None when trigger disabled."""
    with patch.object(escrow_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await escrow_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_no_event(db_session):
    """Auto stage 1 returns None for non-existent event."""
    with patch.object(escrow_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=True):
        result = await escrow_svc.check_and_release_stage1(db_session, event_id=99999)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_already_released(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Auto stage 1 returns None if already released."""
    await _release_stage1(db_session, test_event_approved.id)

    async def mock_get_bool(db, key, **kw):
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="selling_started"):
            result = await escrow_svc.check_and_release_stage1(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_selling_started(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Auto stage 1 fires when mode=selling_started and event is selling."""
    test_event_approved.status = EventStatus.selling_tickets
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    async def mock_get_str(db, key, **kw):
        return "selling_started"

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=30):
                with _trust_patch(0.5):
                    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                        result = await escrow_svc.check_and_release_stage1(
                            db_session, event_id=test_event_approved.id
                        )
    assert result is not None
    assert result.stage1_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage1_selling_started_wrong_status(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """selling_started mode returns None if event not selling_tickets."""
    test_event_approved.status = EventStatus.approved
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="selling_started"):
            result = await escrow_svc.check_and_release_stage1(
                db_session, event_id=test_event_approved.id
            )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_funding_end_not_reached(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """funding_end mode returns None if funding hasn't ended yet."""
    test_event_approved.funding_end_at = datetime.now(timezone.utc) + timedelta(days=10)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="funding_end"):
            result = await escrow_svc.check_and_release_stage1(
                db_session, event_id=test_event_approved.id
            )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_funding_end_reached(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """funding_end mode fires when funding has ended."""
    test_event_approved.funding_end_at = datetime.now(timezone.utc) - timedelta(days=1)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="funding_end"):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=30):
                with _trust_patch(0.5):
                    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                        result = await escrow_svc.check_and_release_stage1(
                            db_session, event_id=test_event_approved.id
                        )
    assert result is not None
    assert result.stage1_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage1_funding_end_no_date(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """funding_end mode returns None if event has no funding_end_at."""
    test_event_approved.funding_end_at = None
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="funding_end"):
            result = await escrow_svc.check_and_release_stage1(
                db_session, event_id=test_event_approved.id
            )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_ticket_percent_below_threshold(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """ticket_percent mode returns None when below threshold."""
    test_event_approved.max_capacity = 100
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="ticket_percent"):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=50):
                result = await escrow_svc.check_and_release_stage1(
                    db_session, event_id=test_event_approved.id
                )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage1_community_waiver(db_session, test_event_approved, test_pledge):
    """Stage 1 auto-check returns waived escrow for community events."""
    test_event_approved.community_rules = True
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True  # both stage1_trigger_enabled and community_escrow_disabled

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        result = await escrow_svc.check_and_release_stage1(
            db_session, event_id=test_event_approved.id
        )
    assert result is not None
    assert result.status == EscrowStatus.waived


# ===========================================================================
# check_and_release_stage2
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage2_disabled(db_session, test_event_approved):
    """Auto stage 2 returns None when trigger disabled."""
    with patch.object(escrow_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await escrow_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage2_no_stage1(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Auto stage 2 returns None if stage 1 not released."""
    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        result = await escrow_svc.check_and_release_stage2(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage2_ticket_percent_fires(db_session, test_event_approved, test_pledge, test_users, test_organizer_bank):
    """Stage 2 auto fires with ticket_percent mode when threshold met."""
    await _release_stage1(db_session, test_event_approved.id)
    test_event_approved.max_capacity = 1
    await db_session.flush()
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"])

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    async def mock_get_str(db, key, **kw):
        return "ticket_percent"

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", side_effect=mock_get_str):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=50):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await escrow_svc.check_and_release_stage2(
                        db_session, event_id=test_event_approved.id
                    )
    assert result is not None
    assert result.stage2_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage2_days_percent_no_dates(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """days_percent mode returns None if no selling start or start_time."""
    await _release_stage1(db_session, test_event_approved.id)
    test_event_approved.start_time = None
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="days_percent"):
            result = await escrow_svc.check_and_release_stage2(
                db_session, event_id=test_event_approved.id
            )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage2_days_percent_fires(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """days_percent mode fires when enough time has elapsed."""
    await _release_stage1(db_session, test_event_approved.id)
    # Set selling start 10 days ago, event start 2 days from now → 83% elapsed
    test_event_approved.ticket_selling_started_at = datetime.now(timezone.utc) - timedelta(days=10)
    test_event_approved.start_time = datetime.now(timezone.utc) + timedelta(days=2)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="days_percent"):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=50):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await escrow_svc.check_and_release_stage2(
                        db_session, event_id=test_event_approved.id
                    )
    assert result is not None
    assert result.stage2_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage2_community_waiver(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Stage 2 auto-check returns waived for community events."""
    await _release_stage1(db_session, test_event_approved.id)
    test_event_approved.community_rules = True
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        result = await escrow_svc.check_and_release_stage2(
            db_session, event_id=test_event_approved.id
        )
    assert result is not None
    assert result.status == EscrowStatus.waived


# ===========================================================================
# check_and_release_stage3
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_stage3_disabled(db_session, test_event_approved):
    """Auto stage 3 returns None when trigger disabled."""
    with patch.object(escrow_svc.settings_svc, "get_bool", new_callable=AsyncMock, return_value=False):
        result = await escrow_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_no_stage2(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Auto stage 3 returns None if stage 2 not released."""
    await _release_stage1(db_session, test_event_approved.id)

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        result = await escrow_svc.check_and_release_stage3(db_session, event_id=test_event_approved.id)
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_days_after_not_reached(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """days_after mode returns None when not enough days have passed."""
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    test_event_approved.end_time = datetime.now(timezone.utc) - timedelta(days=1)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="days_after"):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=7):
                result = await escrow_svc.check_and_release_stage3(
                    db_session, event_id=test_event_approved.id
                )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_days_after_fires(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """days_after mode fires when enough days have passed."""
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    test_event_approved.end_time = datetime.now(timezone.utc) - timedelta(days=10)
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="days_after"):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=7):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await escrow_svc.check_and_release_stage3(
                        db_session, event_id=test_event_approved.id
                    )
    assert result is not None
    assert result.stage3_released_at is not None


@pytest.mark.asyncio
async def test_auto_stage3_days_after_no_end_time(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """days_after mode returns None if event has no end_time."""
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    test_event_approved.end_time = None
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="days_after"):
            result = await escrow_svc.check_and_release_stage3(
                db_session, event_id=test_event_approved.id
            )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_scan_threshold_not_completed(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """scan_threshold mode returns None if event not completed."""
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    test_event_approved.status = EventStatus.approved
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="scan_threshold"):
            result = await escrow_svc.check_and_release_stage3(
                db_session, event_id=test_event_approved.id
            )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_scan_threshold_fires(db_session, test_event_approved, test_pledge, test_users, test_organizer_bank):
    """scan_threshold mode fires when enough tickets scanned."""
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    test_event_approved.status = EventStatus.completed
    await db_session.flush()

    # Create a scanned ticket
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"], scanned=True)

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="scan_threshold"):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=50):
                with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
                    result = await escrow_svc.check_and_release_stage3(
                        db_session, event_id=test_event_approved.id
                    )
    assert result is not None
    assert result.stage3_released_at is not None
    assert result.status == EscrowStatus.fully_released


@pytest.mark.asyncio
async def test_auto_stage3_scan_threshold_below(db_session, test_event_approved, test_pledge, test_users, test_organizer_bank):
    """scan_threshold mode returns None when not enough tickets scanned."""
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    test_event_approved.status = EventStatus.completed
    await db_session.flush()

    # Create an unscanned ticket
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"], scanned=False)

    async def mock_get_bool(db, key, **kw):
        if key == "community_escrow_disabled":
            return False
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        with patch.object(escrow_svc.settings_svc, "get_str", new_callable=AsyncMock, return_value="scan_threshold"):
            with patch.object(escrow_svc.settings_svc, "get_int", new_callable=AsyncMock, return_value=50):
                result = await escrow_svc.check_and_release_stage3(
                    db_session, event_id=test_event_approved.id
                )
    assert result is None


@pytest.mark.asyncio
async def test_auto_stage3_community_waiver(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Stage 3 auto-check returns waived for community events."""
    await _release_stage1(db_session, test_event_approved.id)
    await _release_stage2(db_session, test_event_approved.id)
    test_event_approved.community_rules = True
    await db_session.flush()

    async def mock_get_bool(db, key, **kw):
        return True

    with patch.object(escrow_svc.settings_svc, "get_bool", side_effect=mock_get_bool):
        result = await escrow_svc.check_and_release_stage3(
            db_session, event_id=test_event_approved.id
        )
    assert result is not None
    assert result.status == EscrowStatus.waived


# ===========================================================================
# _ticket_sold_percent
# ===========================================================================

@pytest.mark.asyncio
async def test_ticket_sold_percent_zero_capacity(db_session, test_event_approved):
    """Zero max_capacity returns 0%."""
    pct = await escrow_svc._ticket_sold_percent(db_session, test_event_approved.id, 0)
    assert pct == 0


@pytest.mark.asyncio
async def test_ticket_sold_percent_with_sales(db_session, test_event_approved, test_users):
    """Correctly calculates sold percentage."""
    await _make_ticket_sale(db_session, test_event_approved, test_users["customer"])
    pct = await escrow_svc._ticket_sold_percent(db_session, test_event_approved.id, 10)
    assert pct == 10  # 1 sold out of 10 = 10%
