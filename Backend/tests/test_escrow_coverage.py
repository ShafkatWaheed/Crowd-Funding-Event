"""
Escrow service tests: get_or_create, release stages, freeze/unfreeze, summary.
"""
import pytest
from unittest.mock import patch, AsyncMock

from app.models.escrow import FundEscrow, EscrowStatus, EscrowRelease
from app.models.funding import Funding, FundingStatus
from app.services import escrow as escrow_svc


# ---------------------------------------------------------------------------
# get_or_create
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_escrow_get_or_create(db_session, test_event_approved):
    """get_or_create returns a FundEscrow with correct total."""
    escrow = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow is not None
    assert escrow.event_id == test_event_approved.id
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_escrow_get_or_create_with_pledges(db_session, test_event_approved, test_pledge):
    """get_or_create sums pledged funding net amounts."""
    escrow = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert escrow.total_held_cents == test_pledge.net_to_organizer_cents


@pytest.mark.asyncio
async def test_escrow_get_or_create_idempotent(db_session, test_event_approved):
    """Calling get_or_create twice returns same escrow."""
    e1 = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    e2 = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    assert e1.id == e2.id


# ---------------------------------------------------------------------------
# refresh_total
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_escrow_refresh_total(db_session, test_event_approved, test_pledge, test_users):
    """refresh_total recalculates from pledges."""
    escrow = await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    # Add another pledge
    pledge2 = Funding(
        event_id=test_event_approved.id,
        user_id=test_users["organizer"].id,
        amount_cents=5000,
        platform_cut_cents=500,
        net_to_organizer_cents=4500,
        status=FundingStatus.pledged,
        receipt_number="PLG-TEST-002",
    )
    db_session.add(pledge2)
    await db_session.commit()
    escrow = await escrow_svc.refresh_total(db_session, escrow)
    assert escrow.total_held_cents == test_pledge.net_to_organizer_cents + 4500


# ---------------------------------------------------------------------------
# Release stages
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_release_stage1(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Release stage 1 sets amount and timestamp."""
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            escrow = await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)
    assert escrow.stage1_released_at is not None
    assert escrow.stage1_released_cents > 0
    assert escrow.status == EscrowStatus.partially_released


@pytest.mark.asyncio
async def test_release_stage1_duplicate_fails(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Cannot release stage 1 twice."""
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)
            with pytest.raises(Exception, match="already released"):
                await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)


@pytest.mark.asyncio
async def test_release_stage2_requires_stage1(db_session, test_event_approved, test_pledge):
    """Cannot release stage 2 before stage 1."""
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=40):
        with pytest.raises(Exception, match="Stage 1 must be released"):
            await escrow_svc.release_stage2(db_session, event_id=test_event_approved.id)


@pytest.mark.asyncio
async def test_release_stage2_after_stage1(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Release stage 2 after stage 1."""
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=40):
        escrow = await escrow_svc.release_stage2(db_session, event_id=test_event_approved.id)
    assert escrow.stage2_released_at is not None
    assert escrow.stage2_released_cents > 0


@pytest.mark.asyncio
async def test_release_stage3_after_stage2(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Release stage 3 after stages 1 and 2."""
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=40):
        await escrow_svc.release_stage2(db_session, event_id=test_event_approved.id)
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        escrow = await escrow_svc.release_stage3(db_session, event_id=test_event_approved.id)
    assert escrow.stage3_released_at is not None
    assert escrow.status == EscrowStatus.fully_released


# ---------------------------------------------------------------------------
# Freeze / unfreeze
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_freeze_escrow(db_session, test_event_approved, test_pledge):
    """Freeze escrow sets frozen status."""
    escrow = await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.frozen


@pytest.mark.asyncio
async def test_unfreeze_escrow(db_session, test_event_approved, test_pledge, test_organizer_bank):
    """Unfreeze escrow restores previous status."""
    await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    escrow = await escrow_svc.unfreeze(db_session, event_id=test_event_approved.id)
    assert escrow.status == EscrowStatus.holding


@pytest.mark.asyncio
async def test_release_frozen_escrow_fails(db_session, test_event_approved, test_pledge):
    """Cannot release a frozen escrow."""
    await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            with pytest.raises(Exception, match="frozen"):
                await escrow_svc.release_stage1(db_session, event_id=test_event_approved.id)


# ---------------------------------------------------------------------------
# Escrow summary
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_escrow_summary(db_session, test_event_approved, test_pledge):
    """get_escrow_summary returns correct structure."""
    summary = await escrow_svc.get_escrow_summary(db_session, event_id=test_event_approved.id)
    assert summary["event_id"] == test_event_approved.id
    assert "total_held_cents" in summary
    assert "status" in summary
    assert summary["remaining_cents"] == summary["total_held_cents"]


# ---------------------------------------------------------------------------
# Admin escrow API endpoints
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_escrows(client, db_session, test_event_approved, test_pledge, auth_headers_admin):
    """Admin lists fund escrows."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.commit()
    resp = await client.get("/api/v1/admin/escrows", headers=auth_headers_admin)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_release_stage(client, db_session, test_event_approved, test_pledge, test_organizer_bank, auth_headers_admin):
    """Admin releases escrow stage via API."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.commit()
    with patch("app.services.escrow.settings_svc.get_int", new_callable=AsyncMock, return_value=30):
        with patch("app.services.event.attendance.get_organizer_trust_score", new_callable=AsyncMock, return_value={"trust_score": 0.5}):
            resp = await client.post(
                f"/api/v1/admin/escrows/{test_event_approved.id}/release/1",
                headers=auth_headers_admin,
            )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_freeze_escrow(client, db_session, test_event_approved, test_pledge, auth_headers_admin):
    """Admin freezes escrow via API."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.commit()
    resp = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/freeze",
        headers=auth_headers_admin,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_unfreeze_escrow(client, db_session, test_event_approved, test_pledge, test_organizer_bank, auth_headers_admin):
    """Admin unfreezes escrow via API."""
    await escrow_svc.freeze(db_session, event_id=test_event_approved.id)
    await db_session.commit()
    resp = await client.post(
        f"/api/v1/admin/escrows/{test_event_approved.id}/unfreeze",
        headers=auth_headers_admin,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_admin_escrows_by_event(client, db_session, test_event_approved, test_pledge, auth_headers_admin):
    """Admin gets escrows for specific event."""
    await escrow_svc.get_or_create(db_session, event_id=test_event_approved.id)
    await db_session.commit()
    resp = await client.get(
        f"/api/v1/admin/escrows/by-event/{test_event_approved.id}",
        headers=auth_headers_admin,
    )
    assert resp.status_code == 200
