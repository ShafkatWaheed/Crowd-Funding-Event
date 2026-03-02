"""
Ledger data-access layer.

All SQLAlchemy queries for PaymentMockLedger entries and LedgerEntry
double-entry bookkeeping records live here.
"""
from __future__ import annotations

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ledger_entry import LedgerEntry
from app.models.payment_mock_ledger import (
    MockLedgerStatus,
    PaymentMockLedger,
)


class LedgerRepository:
    """Data-access for mock payment ledger and double-entry bookkeeping."""

    # ── PaymentMockLedger ────────────────────────────────────

    async def get_by_idempotency_key(
        self, db: AsyncSession, key: str
    ) -> PaymentMockLedger | None:
        q = select(PaymentMockLedger).where(
            PaymentMockLedger.idempotency_key == key
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def create_entry(
        self, db: AsyncSession, entry: PaymentMockLedger
    ) -> PaymentMockLedger:
        db.add(entry)
        await db.flush()
        return entry

    async def update_entry_status(
        self, db: AsyncSession, entry: PaymentMockLedger, **kwargs
    ) -> None:
        for k, v in kwargs.items():
            setattr(entry, k, v)
        await db.flush()

    # ── LedgerEntry (double-entry bookkeeping) ───────────────

    async def record_entries(
        self, db: AsyncSession, entries: list[LedgerEntry]
    ) -> list[LedgerEntry]:
        for entry in entries:
            db.add(entry)
        await db.flush()
        return entries

    async def get_total_debits(self, db: AsyncSession) -> int:
        result = (await db.execute(
            select(func.coalesce(func.sum(LedgerEntry.amount_cents), 0)).where(
                LedgerEntry.entry_type == "debit"
            )
        )).scalar_one()
        return int(result)

    async def get_total_credits(self, db: AsyncSession) -> int:
        result = (await db.execute(
            select(func.coalesce(func.sum(LedgerEntry.amount_cents), 0)).where(
                LedgerEntry.entry_type == "credit"
            )
        )).scalar_one()
        return int(result)

    async def get_account_balances(self, db: AsyncSession) -> dict[str, int]:
        q = (
            select(
                LedgerEntry.account,
                func.sum(
                    case(
                        (LedgerEntry.entry_type == "debit", LedgerEntry.amount_cents),
                        else_=-LedgerEntry.amount_cents,
                    )
                ).label("balance"),
            )
            .group_by(LedgerEntry.account)
            .order_by(LedgerEntry.account)
        )
        rows = (await db.execute(q)).all()
        return {row.account: int(row.balance) for row in rows}

    async def get_account_balance(self, db: AsyncSession, account: str) -> int:
        result = (await db.execute(
            select(
                func.coalesce(
                    func.sum(
                        case(
                            (LedgerEntry.entry_type == "debit", LedgerEntry.amount_cents),
                            else_=-LedgerEntry.amount_cents,
                        )
                    ),
                    0,
                )
            ).where(LedgerEntry.account == account)
        )).scalar_one()
        return int(result)


ledger_repo = LedgerRepository()
