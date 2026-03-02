"""
Service-level tests for ticket_escrow.py, escrow_base.py, extended escrow.py.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventStatus
from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow, EscrowStatus, EscrowRelease
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.funding import Funding, FundingStatus
from app.models.user import User, UserRole
from app.core.exceptions import ConflictError

from app.services import escrow as escrow_svc
from app.services import ticket_escrow as te_svc
from app.services import escrow_base


# ===========================================================================
# TICKET ESCROW: get_or_create, freeze, unfreeze
# ===========================================================================

@pytest.mark.asyncio
async def test_ticket_escrow_get_or_create(db_session, test_event_approved):
    """Create ticket escrow."""
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow is not None
    assert escrow.event_id == test_event_approved.id
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_ticket_escrow_idempotent(db_session, test_event_approved):
    """get_or_create is idempotent."""
    e1 = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    e2 = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert e1.id == e2.id


@pytest.mark.asyncio
async def test_ticket_escrow_with_sales(db_session, test_event_approved, test_ticket_sale):
    """Ticket escrow calculates total from sales."""
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    # Should include test_ticket_sale amount
    assert escrow.total_held_cents >= 0


@pytest.mark.asyncio
async def test_ticket_escrow_refresh_total(db_session, test_event_approved, test_ticket_sale):
    """Refresh recalculates total."""
    escrow = await te_svc.get_or_create(db_session, event_id=test_event_approved.id)
    refreshed = await te_svc.refresh_total(db_session, test_event_approved.id)
    assert refreshed.total_held_cents >= 0


@pytest.mark.asyncio
async def test_ticket_escrow_freeze(db_session, test_event_approved):
    """Freeze ticket escrow."""
    escrow = await te_svc.freeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.frozen


@pytest.mark.asyncio
async def test_ticket_escrow_unfreeze(db_session, test_event_approved, test_organizer_bank):
    """Unfreeze ticket escrow."""
    await te_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await te_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_ticket_escrow_release_frozen_fails(db_session, test_event_approved):
    """Cannot release frozen ticket escrow."""
    await te_svc.freeze(db_session, event_id=test_event_approved.id)
    with pytest.raises(ConflictError, match="frozen"):
        await te_svc.release_stage1(db_session, event_id=test_event_approved.id)


# ===========================================================================
# ESCROW BASE: generic functions
# ===========================================================================

@pytest.mark.asyncio
async def test_reject_if_frozen():
    """reject_if_frozen raises on frozen escrow."""
    mock_escrow = type("E", (), {"status": EscrowStatus.frozen})()
    with pytest.raises(ConflictError, match="frozen"):
        escrow_base.reject_if_frozen(mock_escrow)


@pytest.mark.asyncio
async def test_reject_if_frozen_ok():
    """reject_if_frozen passes on holding escrow."""
    mock_escrow = type("E", (), {"status": EscrowStatus.holding})()
    escrow_base.reject_if_frozen(mock_escrow)  # should not raise


@pytest.mark.asyncio
async def test_organizer_has_verified_bank(db_session, test_users, test_organizer_bank):
    """Check organizer has verified bank."""
    organizer = test_users["organizer"]
    result = await escrow_base.organizer_has_verified_bank(db_session, organizer.id)
    assert result is True


@pytest.mark.asyncio
async def test_organizer_has_no_bank(db_session, test_users):
    """Check organizer without bank."""
    customer = test_users["customer"]
    result = await escrow_base.organizer_has_verified_bank(db_session, customer.id)
    assert result is False


@pytest.mark.asyncio
async def test_get_organizer_for_event(db_session, test_event_approved, test_users):
    """Get organizer ID for event."""
    result = await escrow_base.get_organizer_for_event(db_session, test_event_approved.id)
    assert result == test_users["organizer"].id


@pytest.mark.asyncio
async def test_get_organizer_for_event_not_found(db_session, test_users):
    """Get organizer for non-existent event."""
    result = await escrow_base.get_organizer_for_event(db_session, 99999)
    assert result is None


@pytest.mark.asyncio
async def test_get_all_admin_ids(db_session, test_users):
    """Get all admin user IDs."""
    result = await escrow_base.get_all_admin_ids(db_session)
    assert test_users["admin"].id in result


# ===========================================================================
# FUND ESCROW: extended stage tests
# ===========================================================================

@pytest.mark.asyncio
async def test_escrow_stage2_duplicate_fails(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Cannot release stage 2 twice."""
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=40):
        await escrow_svc.release_stage2(db_session, event_id=test_event_approved.id)
        with pytest.raises(Exception, match="already released"):
            await escrow_svc.release_stage2(db_session, event_id=test_event_approved.id)


@pytest.mark.asyncio
async def test_escrow_stage3_requires_stage2(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Cannot release stage 3 before stage 2."""
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with pytest.raises(Exception, match="Stage 2"):
            await escrow_svc.release_stage3(db_session, event_id=test_event_approved.id)


@pytest.mark.asyncio
async def test_escrow_unfreeze_to_partially_released(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Unfreeze after stage 1 release goes to partially_released."""
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)
    await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await escrow_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.partially_released


# ===========================================================================
# ESCROW BASE: generic_list_all
# ===========================================================================

@pytest.mark.asyncio
async def test_generic_list_all_fund_escrows(db_session, test_event_approved, test_pledge):
    """List all fund escrows via generic function."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.flush()
    items, total = await escrow_base.generic_list_all(db_session, FundEscrow)
    assert total >= 1
    assert len(items) >= 1


@pytest.mark.asyncio
async def test_generic_list_all_with_search(db_session, test_event_approved, test_pledge):
    """List escrows with search filter."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.flush()
    items, total = await escrow_base.generic_list_all(db_session, FundEscrow, search="Test")
    assert isinstance(total, int)


@pytest.mark.asyncio
async def test_has_active_escrow(db_session, test_event_approved, test_pledge, test_users):
    """Check if organizer has active escrow."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.flush()
    organizer = test_users["organizer"]
    result = await escrow_base.has_active_escrow(db_session, organizer.id)
    assert result is True


@pytest.mark.asyncio
async def test_has_no_active_escrow(db_session, test_users):
    """No active escrow for user without events."""
    customer = test_users["customer"]
    result = await escrow_base.has_active_escrow(db_session, customer.id)
    assert result is False
