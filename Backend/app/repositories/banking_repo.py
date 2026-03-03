"""
Banking data-access layer.

All SQLAlchemy queries for OrganizerBankAccount, UserPaymentInfo,
Disputes, PaymentMockLedger, EmailMockLog, and ReconciliationReport
queries used by the banking route live here.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import delete as sa_delete, func, or_, select, update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.dispute import Dispute, DisputeStatus
from app.models.email_mock_log import EmailMockLog
from app.models.escrow import EscrowStatus, FundEscrow, TicketEscrow, SponsorEscrow
from app.models.ledger_entry import LedgerEntry
from app.models.payment_info import OrganizerBankAccount, UserPaymentInfo
from app.models.payment_mock_ledger import MockLedgerStatus, PaymentMockLedger
from app.models.reconciliation import ReconciliationReport
from app.models.user import User


class BankingRepository:
    """Pure data-access for banking-related models."""

    # ═══════════════════════════════════════════════════════════════════
    #  UserPaymentInfo
    # ═══════════════════════════════════════════════════════════════════

    async def get_payment_info(
        self, db: AsyncSession, user_id: int
    ) -> UserPaymentInfo | None:
        q = select(UserPaymentInfo).where(UserPaymentInfo.user_id == user_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def create_payment_info(
        self, db: AsyncSession, info: UserPaymentInfo
    ) -> UserPaymentInfo:
        db.add(info)
        await db.flush()
        return info

    async def flush(self, db: AsyncSession) -> None:
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  OrganizerBankAccount
    # ═══════════════════════════════════════════════════════════════════

    async def get_bank_account(
        self, db: AsyncSession, user_id: int
    ) -> OrganizerBankAccount | None:
        q = select(OrganizerBankAccount).where(OrganizerBankAccount.user_id == user_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def create_bank_account(
        self, db: AsyncSession, acct: OrganizerBankAccount
    ) -> OrganizerBankAccount:
        db.add(acct)
        await db.flush()
        return acct

    # ═══════════════════════════════════════════════════════════════════
    #  User (stripe lookups)
    # ═══════════════════════════════════════════════════════════════════

    async def get_user(self, db: AsyncSession, user_id: int) -> User | None:
        q = select(User).where(User.id == user_id)
        return (await db.execute(q)).scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════════
    #  Escrow Aggregates
    # ═══════════════════════════════════════════════════════════════════

    async def get_fund_escrow_aggregates(self, db: AsyncSession) -> tuple:
        """Returns (held, released, count) for active fund escrows."""
        return (await db.execute(
            select(
                func.coalesce(func.sum(FundEscrow.total_held_cents), 0),
                func.coalesce(func.sum(
                    FundEscrow.stage1_released_cents + FundEscrow.stage2_released_cents + FundEscrow.stage3_released_cents
                ), 0),
                func.count(),
            ).where(FundEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]))
        )).one()

    async def get_ticket_escrow_aggregates(self, db: AsyncSession) -> tuple:
        """Returns (held, released, count) for active ticket escrows."""
        return (await db.execute(
            select(
                func.coalesce(func.sum(TicketEscrow.total_held_cents), 0),
                func.coalesce(func.sum(
                    TicketEscrow.stage1_released_cents + TicketEscrow.stage2_released_cents + TicketEscrow.stage3_released_cents
                ), 0),
                func.count(),
            ).where(TicketEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]))
        )).one()

    async def get_sponsor_escrow_aggregates(self, db: AsyncSession) -> tuple:
        """Returns (held, released, count) for active sponsor escrows."""
        return (await db.execute(
            select(
                func.coalesce(func.sum(SponsorEscrow.total_held_cents), 0),
                func.coalesce(func.sum(
                    SponsorEscrow.stage1_released_cents + SponsorEscrow.stage2_released_cents + SponsorEscrow.stage3_released_cents
                ), 0),
                func.count(),
            ).where(SponsorEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]))
        )).one()

    async def get_payout_pending_organizer_count(self, db: AsyncSession) -> int:
        """Count distinct organizers with active escrows."""
        from app.models.event import Event as _Evt
        max_count = 0
        for _EscrowModel in (FundEscrow, TicketEscrow, SponsorEscrow):
            cnt = (await db.execute(
                select(func.count(func.distinct(_Evt.organizer_id)))
                .select_from(_EscrowModel)
                .join(_Evt, _EscrowModel.event_id == _Evt.id)
                .where(_EscrowModel.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]))
            )).scalar_one()
            max_count = max(max_count, int(cnt))
        return max_count

    async def get_escrow_by_event(
        self, db: AsyncSession, event_id: int
    ) -> tuple:
        """Return (fund_escrow, ticket_escrow, sponsor_escrow) for event."""
        fe = (await db.execute(
            select(FundEscrow).where(FundEscrow.event_id == event_id)
        )).scalar_one_or_none()
        te = (await db.execute(
            select(TicketEscrow).where(TicketEscrow.event_id == event_id)
        )).scalar_one_or_none()
        se = (await db.execute(
            select(SponsorEscrow).where(SponsorEscrow.event_id == event_id)
        )).scalar_one_or_none()
        return fe, te, se

    # ═══════════════════════════════════════════════════════════════════
    #  Commission & Tax (Ledger)
    # ═══════════════════════════════════════════════════════════════════

    async def get_commission_by_source(
        self, db: AsyncSession, cutoff: datetime
    ) -> list:
        q = (
            select(
                LedgerEntry.description,
                func.coalesce(func.sum(LedgerEntry.amount_cents), 0),
            )
            .where(
                LedgerEntry.account == "platform_commission",
                LedgerEntry.entry_type == "credit",
                LedgerEntry.created_at >= cutoff,
            )
            .group_by(LedgerEntry.description)
        )
        return list((await db.execute(q)).all())

    async def get_tax_collected_in_period(
        self, db: AsyncSession, cutoff: datetime
    ) -> int:
        q = (
            select(func.coalesce(func.sum(LedgerEntry.amount_cents), 0))
            .where(
                LedgerEntry.account == "tax_collected",
                LedgerEntry.entry_type == "credit",
                LedgerEntry.created_at >= cutoff,
            )
        )
        return abs(int((await db.execute(q)).scalar_one()))

    # ═══════════════════════════════════════════════════════════════════
    #  Disputes
    # ═══════════════════════════════════════════════════════════════════

    async def get_open_dispute_stats(self, db: AsyncSession) -> tuple:
        """Returns (count, total_amount_cents) for open disputes."""
        return (await db.execute(
            select(
                func.count(),
                func.coalesce(func.sum(Dispute.amount_cents), 0),
            ).where(Dispute.status == DisputeStatus.open)
        )).one()

    async def list_disputes(
        self, db: AsyncSession, *, status: str | None = None,
        offset: int = 0, limit: int = 20,
    ) -> tuple[list[Dispute], int]:
        q = select(Dispute)
        if status:
            try:
                q = q.where(Dispute.status == DisputeStatus(status))
            except ValueError:
                pass
        total = int((await db.execute(
            select(func.count()).select_from(q.subquery())
        )).scalar_one())
        rows = list((await db.execute(
            q.order_by(Dispute.created_at.desc()).offset(offset).limit(limit)
        )).scalars().all())
        return rows, total

    async def get_dispute(self, db: AsyncSession, dispute_id: int) -> Dispute | None:
        q = select(Dispute).where(Dispute.id == dispute_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def create_dispute(self, db: AsyncSession, dispute: Dispute) -> Dispute:
        db.add(dispute)
        await db.flush()
        return dispute

    # ═══════════════════════════════════════════════════════════════════
    #  Reconciliation Reports
    # ═══════════════════════════════════════════════════════════════════

    async def get_latest_reconciliation(self, db: AsyncSession) -> ReconciliationReport | None:
        q = select(ReconciliationReport).order_by(ReconciliationReport.run_date.desc()).limit(1)
        return (await db.execute(q)).scalar_one_or_none()

    async def list_reconciliation_reports(
        self, db: AsyncSession, limit: int = 30
    ) -> list[ReconciliationReport]:
        q = select(ReconciliationReport).order_by(ReconciliationReport.run_date.desc()).limit(limit)
        return list((await db.execute(q)).scalars().all())

    # ═══════════════════════════════════════════════════════════════════
    #  Mock Ledger
    # ═══════════════════════════════════════════════════════════════════

    async def get_mock_ledger_by_transaction_id(
        self, db: AsyncSession, transaction_id: str
    ) -> PaymentMockLedger | None:
        q = select(PaymentMockLedger).where(PaymentMockLedger.transaction_id == transaction_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def get_mock_ledger_overview(self, db: AsyncSession) -> dict:
        """Return transaction counts, volume, last time, and recent transactions."""
        total = int((await db.execute(
            select(func.count()).select_from(PaymentMockLedger)
        )).scalar_one())
        volume = int((await db.execute(
            select(func.coalesce(func.sum(PaymentMockLedger.amount_cents), 0))
        )).scalar_one())
        success = int((await db.execute(
            select(func.count()).select_from(PaymentMockLedger).where(
                PaymentMockLedger.status.in_([
                    MockLedgerStatus.completed, MockLedgerStatus.settled, MockLedgerStatus.settlement_pending,
                ])
            )
        )).scalar_one())
        last_txn = (await db.execute(
            select(func.max(PaymentMockLedger.created_at))
        )).scalar_one_or_none()
        recent = list((await db.execute(
            select(PaymentMockLedger).order_by(PaymentMockLedger.created_at.desc()).limit(20)
        )).scalars().all())
        return {
            "total": total,
            "volume": volume,
            "success": success,
            "last_txn": last_txn,
            "recent": recent,
        }

    async def get_email_mock_overview(self, db: AsyncSession) -> dict:
        """Return email log counts and recent logs."""
        total = int((await db.execute(
            select(func.count()).select_from(EmailMockLog)
        )).scalar_one())
        bounced = int((await db.execute(
            select(func.count()).select_from(EmailMockLog).where(EmailMockLog.status == "bounced")
        )).scalar_one())
        last_email = (await db.execute(
            select(func.max(EmailMockLog.created_at))
        )).scalar_one_or_none()
        recent = list((await db.execute(
            select(EmailMockLog).order_by(EmailMockLog.created_at.desc()).limit(20)
        )).scalars().all())
        return {
            "total": total,
            "bounced": bounced,
            "last_email": last_email,
            "recent": recent,
        }

    async def delete_all_mock_data(self, db: AsyncSession) -> tuple[int, int]:
        """Delete all mock ledger and email log entries. Returns (ledger_count, email_count)."""
        r1 = await db.execute(sa_delete(PaymentMockLedger))
        r2 = await db.execute(sa_delete(EmailMockLog))
        await db.flush()
        return r1.rowcount, r2.rowcount

    async def settle_all_pending(self, db: AsyncSession) -> int:
        """Mark all settlement_pending mock ledger entries as settled."""
        r = await db.execute(
            sa_update(PaymentMockLedger)
            .where(PaymentMockLedger.status == MockLedgerStatus.settlement_pending)
            .values(
                status=MockLedgerStatus.settled,
                completed_at=datetime.now(timezone.utc),
            )
        )
        await db.flush()
        return r.rowcount

    async def get_txn_status_counts(self, db: AsyncSession) -> dict:
        """Get transaction count breakdown by status."""
        total = int((await db.execute(
            select(func.count(PaymentMockLedger.id))
        )).scalar_one())
        settled = int((await db.execute(
            select(func.count(PaymentMockLedger.id)).where(
                PaymentMockLedger.status == MockLedgerStatus.settled)
        )).scalar_one())
        pending = int((await db.execute(
            select(func.count(PaymentMockLedger.id)).where(
                PaymentMockLedger.status == MockLedgerStatus.pending)
        )).scalar_one())
        failed = int((await db.execute(
            select(func.count(PaymentMockLedger.id)).where(
                PaymentMockLedger.status == MockLedgerStatus.failed)
        )).scalar_one())
        return {"total": total, "settled": settled, "pending": pending, "failed": failed}

    async def list_transactions(
        self, db: AsyncSession, *, offset: int = 0, limit: int = 20,
        operation: str | None = None, status: str | None = None,
        date_from: datetime | None = None, date_to: datetime | None = None,
        search: str | None = None,
    ) -> tuple[list[PaymentMockLedger], int]:
        from app.models.payment_mock_ledger import MockLedgerOperation

        q = select(PaymentMockLedger)
        if operation:
            try:
                q = q.where(PaymentMockLedger.operation == MockLedgerOperation(operation))
            except ValueError:
                pass
        if status:
            try:
                q = q.where(PaymentMockLedger.status == MockLedgerStatus(status))
            except ValueError:
                pass
        if date_from:
            q = q.where(PaymentMockLedger.created_at >= date_from)
        if date_to:
            q = q.where(PaymentMockLedger.created_at <= date_to)
        if search:
            pattern = f"%{search}%"
            q = q.where(or_(
                PaymentMockLedger.transaction_id.ilike(pattern),
                PaymentMockLedger.receipt_reference.ilike(pattern),
                PaymentMockLedger.description.ilike(pattern),
            ))
        total = int((await db.execute(
            select(func.count()).select_from(q.subquery())
        )).scalar_one())
        rows = list((await db.execute(
            q.order_by(PaymentMockLedger.created_at.desc()).offset(offset).limit(limit)
        )).scalars().all())
        return rows, total


    # ═══════════════════════════════════════════════════════════════════
    #  Payout Status (admin)
    # ═══════════════════════════════════════════════════════════════════

    async def list_organizer_users(self, db: AsyncSession) -> list:
        """Return (id, display_name, email) for all organizers."""
        from app.models.user import UserRole
        q = (
            select(User.id, User.display_name, User.email)
            .where(User.role == UserRole.organizer)
            .order_by(User.display_name)
        )
        return list((await db.execute(q)).all())

    async def get_released_escrow_cents_for_organizer(
        self, db: AsyncSession, organizer_id: int
    ) -> int:
        """Sum released escrow cents across all escrow types for one organizer."""
        from app.models.event import Event as _Evt
        total = 0
        for _EscrowModel in (FundEscrow, TicketEscrow, SponsorEscrow):
            released = (await db.execute(
                select(func.coalesce(func.sum(
                    _EscrowModel.stage1_released_cents
                    + _EscrowModel.stage2_released_cents
                    + _EscrowModel.stage3_released_cents
                ), 0))
                .join(_Evt, _EscrowModel.event_id == _Evt.id)
                .where(_Evt.organizer_id == organizer_id)
            )).scalar_one()
            total += int(released)
        return total

    # ── Worker task helpers ────────────────────────────────────────

    async def get_account_by_id(
        self, db: AsyncSession, bank_account_id: int,
    ) -> OrganizerBankAccount | None:
        q = select(OrganizerBankAccount).where(OrganizerBankAccount.id == bank_account_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def list_all_accounts(self, db: AsyncSession) -> list[OrganizerBankAccount]:
        q = select(OrganizerBankAccount)
        return list((await db.execute(q)).scalars().all())


# Module-level singleton
banking_repo = BankingRepository()
