"""
Daily reconciliation: compares ledger balances against mock/real bank balance.
"""
from __future__ import annotations

from datetime import date

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.reconciliation import ReconciliationReport
from app.repositories.admin_repo import admin_repo
from app.services import ledger as ledger_svc
from app.services import platform_settings as settings_svc

logger = get_logger("svc.reconciliation")


async def run_reconciliation(db: AsyncSession) -> ReconciliationReport:
    """Run a reconciliation check and store the result."""
    today = date.today()
    log_step(logger, "Running reconciliation", run_date=str(today))

    existing = await admin_repo.get_reconciliation_report(db, today)
    if existing:
        await admin_repo.delete_reconciliation_report(db, existing)

    mock_active = await settings_svc.get_bool(db, "payment_mock_enabled")

    if mock_active:
        actual_balance = await admin_repo.get_mock_ledger_actual_balance(db)
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
    if status == "discrepancy":
        logger.warning(
            "Reconciliation delta mismatch",
            extra={
                "actual_balance_cents": actual_balance,
                "expected_balance_cents": expected,
                "delta_cents": delta,
            },
        )

    report = ReconciliationReport(
        run_date=today,
        actual_balance_cents=actual_balance,
        expected_balance_cents=expected,
        delta_cents=delta,
        status=status,
    )
    await admin_repo.create_reconciliation_report(db, report)
    logger.info("Reconciliation run completed", extra={"run_date": str(today), "status": status, "delta_cents": delta})
    return report
