"""
Service-level tests for payment_gateway.py (MockPaymentGateway).
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.services.payment_gateway import get_gateway, MockPaymentGateway, ChargeResult


# ===========================================================================
# get_gateway
# ===========================================================================

@pytest.mark.asyncio
async def test_get_gateway_mock(db_session, test_users):
    """get_gateway returns MockPaymentGateway when stripe not enabled."""
    gw = await get_gateway(db_session)
    assert isinstance(gw, MockPaymentGateway)


# ===========================================================================
# MockPaymentGateway.charge
# ===========================================================================

@pytest.mark.asyncio
async def test_charge_success(db_session, test_users):
    """Mock gateway charge succeeds."""
    gw = MockPaymentGateway()
    with patch("app.services.payment_gateway.settings_svc.get_bool", new_callable=AsyncMock, return_value=False):
        with patch("app.services.payment_gateway.settings_svc.get_int", new_callable=AsyncMock, return_value=0):
            with patch("app.services.payment_gateway.settings_svc.get_float", new_callable=AsyncMock, return_value=0.0):
                with patch("app.services.ledger.record_charge", new_callable=AsyncMock):
                    result = await gw.charge(
                        db_session,
                        user_id=test_users["customer"].id,
                        amount_cents=5000,
                        description="Test charge",
                    )
    assert result.status == "completed"
    assert result.transaction_id is not None


@pytest.mark.asyncio
async def test_charge_with_commission(db_session, test_users):
    """Mock charge with commission."""
    gw = MockPaymentGateway()
    with patch("app.services.payment_gateway.settings_svc.get_bool", new_callable=AsyncMock, return_value=False):
        with patch("app.services.payment_gateway.settings_svc.get_int", new_callable=AsyncMock, return_value=0):
            with patch("app.services.payment_gateway.settings_svc.get_float", new_callable=AsyncMock, return_value=0.0):
                with patch("app.services.ledger.record_charge", new_callable=AsyncMock):
                    result = await gw.charge(
                        db_session,
                        user_id=test_users["customer"].id,
                        amount_cents=10000,
                        description="Test charge",
                        commission_cents=500,
                    )
    assert result.status == "completed"


@pytest.mark.asyncio
async def test_charge_forced_failure(db_session, test_users):
    """Mock charge can be forced to fail."""
    gw = MockPaymentGateway()
    with patch("app.services.payment_gateway.settings_svc.get_bool", new_callable=AsyncMock) as mock_bool:
        mock_bool.side_effect = lambda db, key, **kw: True if key == "mock_fail_next_charge" else False
        with patch("app.services.payment_gateway.settings_svc.get_int", new_callable=AsyncMock, return_value=0):
            with patch("app.services.payment_gateway.settings_svc.get_float", new_callable=AsyncMock, return_value=0.0):
                with patch("app.services.payment_gateway.settings_svc.set_value", new_callable=AsyncMock):
                    result = await gw.charge(
                        db_session,
                        user_id=test_users["customer"].id,
                        amount_cents=5000,
                        description="Test charge",
                    )
    assert result.status == "failed"


# ===========================================================================
# MockPaymentGateway.transfer
# ===========================================================================

@pytest.mark.asyncio
async def test_transfer(db_session, test_users):
    """Mock gateway transfer."""
    gw = MockPaymentGateway()
    with patch("app.services.payment_gateway.settings_svc.get_int", new_callable=AsyncMock, return_value=0):
        with patch("app.services.ledger.record_entries", new_callable=AsyncMock):
            result = await gw.transfer(
                db_session,
                from_account="holding_account",
                to_account="organizer_account",
                amount_cents=3000,
                description="Test transfer",
            )
    assert result.status == "completed"


# ===========================================================================
# MockPaymentGateway.refund
# ===========================================================================

@pytest.mark.asyncio
async def test_refund(db_session, test_users):
    """Mock gateway refund."""
    gw = MockPaymentGateway()
    with patch("app.services.payment_gateway.settings_svc.get_int", new_callable=AsyncMock, return_value=0):
        with patch("app.services.ledger.record_entries", new_callable=AsyncMock):
            result = await gw.refund(
                db_session,
                original_transaction_id="txn-test-001",
                amount_cents=2000,
                description="Test refund",
            )
    assert result.status == "completed"


# ===========================================================================
# MockPaymentGateway.hold and release_hold
# ===========================================================================

@pytest.mark.asyncio
async def test_hold(db_session, test_users):
    """Mock gateway hold."""
    gw = MockPaymentGateway()
    with patch("app.services.ledger.record_entries", new_callable=AsyncMock):
        result = await gw.hold(
            db_session,
            account="holding_account",
            amount_cents=1000,
            description="Test hold",
        )
    assert result.status == "completed"


@pytest.mark.asyncio
async def test_release_hold(db_session, test_users):
    """Mock gateway release hold."""
    gw = MockPaymentGateway()
    with patch("app.services.payment_gateway.settings_svc.get_int", new_callable=AsyncMock, return_value=0):
        with patch("app.services.ledger.record_entries", new_callable=AsyncMock):
            result = await gw.release_hold(
                db_session,
                hold_id="hold-test-001",
                to_account="organizer_account",
                amount_cents=1000,
            )
    assert result.status in ("settled", "settlement_pending")
