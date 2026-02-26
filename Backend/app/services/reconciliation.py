"""
Daily reconciliation: compares ledger balances against mock/real bank balance.
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payment_mock_ledger import MockLedgerStatus, PaymentMockLedger
from app.models.reconciliation import ReconciliationReport
from app.services import ledger as ledger_svc
from app.services import platform_settings as settings_svc


async def run_reconciliation(db: AsyncSession) -> ReconciliationReport:
    """Run a reconciliation check and store the result."""
    today = date.today()

    existing = (await db.execute(
        select(ReconciliationReport).where(ReconciliationReport.run_date == today)
    )).scalar_one_or_none()
    if existing:
        await db.delete(existing)
        await db.flush()

    mock_active = await settings_svc.get_bool(db, "payment_mock_enabled")

    if mock_active:
        actual = (await db.execute(
            select(func.coalesce(func.sum(PaymentMockLedger.amount_cents), 0)).where(
                PaymentMockLedger.status.in_([
                    MockLedgerStatus.completed,
                    MockLedgerStatus.settled,
                    MockLedgerStatus.settlement_pending,
                ])
            )
        )).scalar_one()
        actual_balance = int(actual)
    else:
        actual_balance = 0

    ledger_data = await ledger_svc.verify_balance(db)
    accounts = ledger_data.get("accounts", {})

    expected = 0
    for acct_name in ("escrow_fund", "escrow_ticket", "escrow_sponsor",
                       "platform_commission", "tax_collected"):
        expected += abs(accounts.get(acct_name, 0))

    delta = actual_balance - expected
    status = "balanced" if abs(delta) <= 100 else "discrepancy"

    report = ReconciliationReport(
        run_date=today,
        actual_balance_cents=actual_balance,
        expected_balance_cents=expected,
        delta_cents=delta,
        status=status,
    )
    db.add(report)
    await db.flush()
    return report
