"""
Reconciliation service tests: report creation, idempotency, discrepancy detection.
"""
import pytest
from unittest.mock import patch, AsyncMock

from app.services.reconciliation import run_reconciliation

from tests.conftest import SKIP_DB

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


@patch("app.services.reconciliation.ledger_svc.verify_balance", new_callable=AsyncMock)
async def test_daily_reconciliation_creates_report(
    mock_verify,
    db_session,
):
    """run_reconciliation creates a ReconciliationReport with correct status."""
    mock_verify.return_value = {"accounts": {}}

    report = await run_reconciliation(db_session)

    assert report is not None
    assert report.status in ("balanced", "discrepancy")
    assert report.run_date is not None
    assert report.delta_cents is not None


@patch("app.services.reconciliation.ledger_svc.verify_balance", new_callable=AsyncMock)
async def test_reconciliation_replaces_existing_report(
    mock_verify,
    db_session,
):
    """Running reconciliation twice on the same day replaces the previous report."""
    mock_verify.return_value = {"accounts": {}}

    report1 = await run_reconciliation(db_session)
    await db_session.commit()

    report2 = await run_reconciliation(db_session)
    await db_session.commit()

    # Both should be for today, second run replaces first
    assert report2.run_date == report1.run_date
    assert report2.id != report1.id


@patch("app.services.reconciliation.ledger_svc.verify_balance", new_callable=AsyncMock)
async def test_reconciliation_detects_discrepancy(
    mock_verify,
    db_session,
):
    """When actual vs expected balance differs by >100 cents, status is 'discrepancy'."""
    # Simulate ledger returning a large expected balance
    mock_verify.return_value = {
        "accounts": {
            "escrow_fund": 500000,
            "platform_commission": 50000,
        }
    }

    report = await run_reconciliation(db_session)

    # actual_balance is 0 (no mock ledger entries), expected is 550000
    assert report.status == "discrepancy"
    assert report.delta_cents != 0
    assert report.actual_balance_cents == 0
    assert report.expected_balance_cents == 550000
