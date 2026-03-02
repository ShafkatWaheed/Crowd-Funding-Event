"""
Double-entry bookkeeping ledger service.

Every financial transaction creates balanced debit/credit entries.
Provides balance verification and per-account summaries.
"""
from __future__ import annotations

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ledger_entry import LedgerEntry
from app.repositories.ledger_repo import ledger_repo

logger = get_logger("svc.ledger")


async def record_entries(
    db: AsyncSession,
    *,
    transaction_id: str,
    entries: list[dict],
) -> list[LedgerEntry]:
    """Record a set of balanced ledger entries for a transaction.

    Each entry dict: {"type": "debit"|"credit", "account": str, "amount_cents": int, "description": str}
    """
    log_step(logger, "Recording ledger entries", transaction_id=transaction_id, entry_count=len(entries))
    rows = [
        LedgerEntry(
            transaction_id=transaction_id,
            entry_type=e["type"],
            account=e["account"],
            amount_cents=e["amount_cents"],
            description=e.get("description", ""),
        )
        for e in entries
    ]
    rows = await ledger_repo.record_entries(db, rows)
    logger.info("Ledger entries recorded", extra={"transaction_id": transaction_id, "entry_count": len(rows)})
    return rows


async def record_charge(
    db: AsyncSession,
    *,
    transaction_id: str,
    customer_id: int,
    total_cents: int,
    escrow_account: str,
    escrow_cents: int,
    commission_cents: int,
    stripe_fee_cents: int,
    tax_cents: int,
    description: str = "",
) -> list[LedgerEntry]:
    """Record a full charge with fee/tax breakdown."""
    log_step(logger, "Recording charge", transaction_id=transaction_id, customer_id=customer_id, total_cents=total_cents)
    entries = [
        {"type": "debit", "account": f"customer_{customer_id}",
         "amount_cents": total_cents, "description": description},
    ]
    if escrow_cents > 0:
        entries.append({"type": "credit", "account": escrow_account,
                        "amount_cents": escrow_cents, "description": f"Escrow hold: {description}"})
    if commission_cents > 0:
        entries.append({"type": "credit", "account": "platform_commission",
                        "amount_cents": commission_cents, "description": f"Commission: {description}"})
    if stripe_fee_cents > 0:
        entries.append({"type": "credit", "account": "stripe_fees",
                        "amount_cents": stripe_fee_cents, "description": f"Processing fee: {description}"})
    if tax_cents > 0:
        entries.append({"type": "credit", "account": "tax_collected",
                        "amount_cents": tax_cents, "description": f"Tax: {description}"})
    return await record_entries(db, transaction_id=transaction_id, entries=entries)


async def verify_balance(db: AsyncSession) -> dict:
    """Verify total debits equal total credits and return per-account balances."""
    log_step(logger, "Verifying ledger balance")
    total_debits = await ledger_repo.get_total_debits(db)
    total_credits = await ledger_repo.get_total_credits(db)
    accounts = await ledger_repo.get_account_balances(db)

    delta = total_debits - total_credits
    balanced = total_debits == total_credits
    logger.debug(
        "Balance verification",
        extra={
            "total_debits_cents": total_debits,
            "total_credits_cents": total_credits,
            "balanced": balanced,
            "delta_cents": delta,
            "account_count": len(accounts),
        },
    )
    return {
        "total_debits_cents": total_debits,
        "total_credits_cents": total_credits,
        "balanced": balanced,
        "delta_cents": delta,
        "accounts": accounts,
    }


async def get_account_balance(db: AsyncSession, account: str) -> int:
    """Get the net balance of a specific account (debits - credits)."""
    return await ledger_repo.get_account_balance(db, account)
