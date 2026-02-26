"""
Double-entry bookkeeping ledger service.

Every financial transaction creates balanced debit/credit entries.
Provides balance verification and per-account summaries.
"""
from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ledger_entry import LedgerEntry


async def record_entries(
    db: AsyncSession,
    *,
    transaction_id: str,
    entries: list[dict],
) -> list[LedgerEntry]:
    """Record a set of balanced ledger entries for a transaction.

    Each entry dict: {"type": "debit"|"credit", "account": str, "amount_cents": int, "description": str}
    """
    rows = []
    for e in entries:
        row = LedgerEntry(
            transaction_id=transaction_id,
            entry_type=e["type"],
            account=e["account"],
            amount_cents=e["amount_cents"],
            description=e.get("description", ""),
        )
        db.add(row)
        rows.append(row)
    await db.flush()
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
    total_debits = (await db.execute(
        select(func.coalesce(func.sum(LedgerEntry.amount_cents), 0)).where(
            LedgerEntry.entry_type == "debit"
        )
    )).scalar_one()

    total_credits = (await db.execute(
        select(func.coalesce(func.sum(LedgerEntry.amount_cents), 0)).where(
            LedgerEntry.entry_type == "credit"
        )
    )).scalar_one()

    account_balances_q = (
        select(
            LedgerEntry.account,
            func.sum(
                func.case(
                    (LedgerEntry.entry_type == "debit", LedgerEntry.amount_cents),
                    else_=-LedgerEntry.amount_cents,
                )
            ).label("balance"),
        )
        .group_by(LedgerEntry.account)
        .order_by(LedgerEntry.account)
    )
    rows = (await db.execute(account_balances_q)).all()
    accounts = {row.account: int(row.balance) for row in rows}

    return {
        "total_debits_cents": int(total_debits),
        "total_credits_cents": int(total_credits),
        "balanced": int(total_debits) == int(total_credits),
        "delta_cents": int(total_debits) - int(total_credits),
        "accounts": accounts,
    }


async def get_account_balance(db: AsyncSession, account: str) -> int:
    """Get the net balance of a specific account (debits - credits)."""
    result = (await db.execute(
        select(
            func.coalesce(
                func.sum(
                    func.case(
                        (LedgerEntry.entry_type == "debit", LedgerEntry.amount_cents),
                        else_=-LedgerEntry.amount_cents,
                    )
                ),
                0,
            )
        ).where(LedgerEntry.account == account)
    )).scalar_one()
    return int(result)
