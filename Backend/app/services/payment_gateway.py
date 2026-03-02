"""
Payment gateway abstraction with mock implementation.

PaymentGateway ABC defines the interface. MockPaymentGateway simulates all
operations with configurable latency, failure rates, and idempotency support.
Factory function get_gateway() returns the appropriate implementation based on
the payment_mock_enabled platform setting.
"""
from __future__ import annotations

import asyncio
import random
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payment_mock_ledger import (
    MockLedgerOperation,
    MockLedgerStatus,
    PaymentMockLedger,
)
from app.repositories.ledger_repo import ledger_repo
from app.services import platform_settings as settings_svc

from app.logger import get_logger

logger = get_logger(__name__)

FAILURE_REASONS = [
    ("card_declined", 60),
    ("gateway_timeout", 25),
    ("fraud_flagged", 15),
]


@dataclass
class ChargeResult:
    transaction_id: str
    status: str
    authorization_code: str
    receipt_reference: str | None = None


@dataclass
class TransferResult:
    transaction_id: str
    status: str
    authorization_code: str
    receipt_reference: str | None = None


@dataclass
class RefundResult:
    transaction_id: str
    status: str
    authorization_code: str
    receipt_reference: str | None = None


@dataclass
class HoldResult:
    transaction_id: str
    status: str
    authorization_code: str


class PaymentGateway(ABC):
    @abstractmethod
    async def charge(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        amount_cents: int,
        description: str,
        idempotency_key: str | None = None,
        escrow_account: str = "holding_account",
        commission_cents: int = 0,
        tax_cents: int = 0,
    ) -> ChargeResult: ...

    @abstractmethod
    async def transfer(
        self,
        db: AsyncSession,
        *,
        from_account: str,
        to_account: str,
        amount_cents: int,
        description: str,
    ) -> TransferResult: ...

    @abstractmethod
    async def refund(
        self,
        db: AsyncSession,
        *,
        original_transaction_id: str,
        amount_cents: int,
        description: str,
    ) -> RefundResult: ...

    @abstractmethod
    async def hold(
        self,
        db: AsyncSession,
        *,
        account: str,
        amount_cents: int,
        description: str,
    ) -> HoldResult: ...

    @abstractmethod
    async def release_hold(
        self,
        db: AsyncSession,
        *,
        hold_id: str,
        to_account: str,
        amount_cents: int,
    ) -> TransferResult: ...


def _pick_failure_reason() -> str:
    roll = random.randint(1, 100)
    cumulative = 0
    for reason, weight in FAILURE_REASONS:
        cumulative += weight
        if roll <= cumulative:
            return reason
    return "card_declined"


class MockPaymentGateway(PaymentGateway):
    """Simulates all payment operations with configurable latency and failure."""

    async def _should_fail(self, db: AsyncSession) -> str | None:
        fail_next = await settings_svc.get_bool(db, "mock_fail_next_charge")
        if fail_next:
            await settings_svc.set_value(db, "mock_fail_next_charge", "false")
            return _pick_failure_reason()
        rate = await settings_svc.get_int(db, "mock_failure_rate_percent")
        if rate > 0 and random.randint(1, 100) <= rate:
            return _pick_failure_reason()
        return None

    async def _latency(self, db: AsyncSession, min_key: str, max_key: str) -> None:
        min_ms = await settings_svc.get_int(db, min_key)
        max_ms = await settings_svc.get_int(db, max_key)
        if min_ms <= 0:
            min_ms = 100
        if max_ms <= min_ms:
            max_ms = min_ms + 500
        delay = random.randint(min_ms, max_ms) / 1000.0
        await asyncio.sleep(delay)

    async def charge(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        amount_cents: int,
        description: str,
        idempotency_key: str | None = None,
        escrow_account: str = "holding_account",
        commission_cents: int = 0,
        tax_cents: int = 0,
    ) -> ChargeResult:
        if idempotency_key:
            existing = await ledger_repo.get_by_idempotency_key(db, idempotency_key)
            if existing:
                return ChargeResult(
                    transaction_id=existing.transaction_id,
                    status=existing.status.value,
                    authorization_code=existing.authorization_code or "",
                    receipt_reference=existing.receipt_reference,
                )

        fee_pct = await settings_svc.get_float(db, "mock_stripe_fee_percent")
        fee_fixed = await settings_svc.get_int(db, "mock_stripe_fee_fixed_cents")
        fee_cents = int(amount_cents * fee_pct / 100) + fee_fixed

        txn_id = uuid.uuid4().hex
        auth_code = f"auth_{uuid.uuid4().hex[:8]}"
        now = datetime.now(timezone.utc)

        entry = PaymentMockLedger(
            transaction_id=txn_id,
            idempotency_key=idempotency_key,
            operation=MockLedgerOperation.charge,
            amount_cents=amount_cents,
            fee_cents=fee_cents,
            from_account=f"customer_{user_id}",
            to_account=escrow_account,
            description=description,
            status=MockLedgerStatus.processing,
            authorization_code=auth_code,
            processing_at=now,
            created_at=now,
        )
        await ledger_repo.create_entry(db, entry)

        await self._latency(db, "mock_charge_latency_min_ms", "mock_charge_latency_max_ms")

        failure = await self._should_fail(db)
        if failure:
            await ledger_repo.update_entry_status(
                db, entry,
                status=MockLedgerStatus.failed,
                failure_reason=failure,
                completed_at=datetime.now(timezone.utc),
            )
            return ChargeResult(
                transaction_id=txn_id, status="failed",
                authorization_code=auth_code,
            )

        await ledger_repo.update_entry_status(
            db, entry,
            status=MockLedgerStatus.completed,
            completed_at=datetime.now(timezone.utc),
        )

        escrow_net = amount_cents - commission_cents - fee_cents - tax_cents
        from app.services import ledger as ledger_svc
        await ledger_svc.record_charge(
            db,
            transaction_id=txn_id,
            customer_id=user_id,
            total_cents=amount_cents,
            escrow_account=escrow_account,
            escrow_cents=max(0, escrow_net),
            commission_cents=commission_cents,
            stripe_fee_cents=fee_cents,
            tax_cents=tax_cents,
            description=description,
        )

        return ChargeResult(
            transaction_id=txn_id, status="completed",
            authorization_code=auth_code,
        )

    async def transfer(
        self,
        db: AsyncSession,
        *,
        from_account: str,
        to_account: str,
        amount_cents: int,
        description: str,
    ) -> TransferResult:
        txn_id = uuid.uuid4().hex
        auth_code = f"auth_{uuid.uuid4().hex[:8]}"
        now = datetime.now(timezone.utc)

        entry = PaymentMockLedger(
            transaction_id=txn_id,
            operation=MockLedgerOperation.transfer,
            amount_cents=amount_cents,
            from_account=from_account,
            to_account=to_account,
            description=description,
            status=MockLedgerStatus.processing,
            authorization_code=auth_code,
            processing_at=now,
            created_at=now,
        )
        await ledger_repo.create_entry(db, entry)

        await self._latency(db, "mock_transfer_latency_min_ms", "mock_transfer_latency_max_ms")

        await ledger_repo.update_entry_status(
            db, entry,
            status=MockLedgerStatus.completed,
            completed_at=datetime.now(timezone.utc),
        )

        from app.services import ledger as ledger_svc
        await ledger_svc.record_entries(db, transaction_id=txn_id, entries=[
            {"type": "debit", "account": from_account, "amount_cents": amount_cents,
             "description": description},
            {"type": "credit", "account": to_account, "amount_cents": amount_cents,
             "description": description},
        ])

        return TransferResult(
            transaction_id=txn_id, status="completed",
            authorization_code=auth_code,
        )

    async def refund(
        self,
        db: AsyncSession,
        *,
        original_transaction_id: str,
        amount_cents: int,
        description: str,
    ) -> RefundResult:
        txn_id = uuid.uuid4().hex
        auth_code = f"auth_{uuid.uuid4().hex[:8]}"
        now = datetime.now(timezone.utc)

        entry = PaymentMockLedger(
            transaction_id=txn_id,
            operation=MockLedgerOperation.refund,
            amount_cents=amount_cents,
            from_account="holding_account",
            to_account=f"refund_{original_transaction_id}",
            description=description,
            status=MockLedgerStatus.processing,
            authorization_code=auth_code,
            processing_at=now,
            created_at=now,
        )
        await ledger_repo.create_entry(db, entry)

        await self._latency(db, "mock_refund_latency_min_ms", "mock_refund_latency_max_ms")

        await ledger_repo.update_entry_status(
            db, entry,
            status=MockLedgerStatus.completed,
            completed_at=datetime.now(timezone.utc),
        )

        from app.services import ledger as ledger_svc
        await ledger_svc.record_entries(db, transaction_id=txn_id, entries=[
            {"type": "debit", "account": "holding_account", "amount_cents": amount_cents,
             "description": description},
            {"type": "credit", "account": f"refund_{original_transaction_id}", "amount_cents": amount_cents,
             "description": description},
        ])

        return RefundResult(
            transaction_id=txn_id, status="completed",
            authorization_code=auth_code,
        )

    async def hold(
        self,
        db: AsyncSession,
        *,
        account: str,
        amount_cents: int,
        description: str,
    ) -> HoldResult:
        txn_id = uuid.uuid4().hex
        auth_code = f"auth_{uuid.uuid4().hex[:8]}"
        now = datetime.now(timezone.utc)

        entry = PaymentMockLedger(
            transaction_id=txn_id,
            operation=MockLedgerOperation.hold,
            amount_cents=amount_cents,
            from_account="holding_account",
            to_account=account,
            description=description,
            status=MockLedgerStatus.completed,
            authorization_code=auth_code,
            processing_at=now,
            completed_at=now,
            created_at=now,
        )
        await ledger_repo.create_entry(db, entry)

        from app.services import ledger as ledger_svc
        await ledger_svc.record_entries(db, transaction_id=txn_id, entries=[
            {"type": "debit", "account": "holding_account", "amount_cents": amount_cents,
             "description": description},
            {"type": "credit", "account": account, "amount_cents": amount_cents,
             "description": description},
        ])

        return HoldResult(
            transaction_id=txn_id, status="completed",
            authorization_code=auth_code,
        )

    async def release_hold(
        self,
        db: AsyncSession,
        *,
        hold_id: str,
        to_account: str,
        amount_cents: int,
    ) -> TransferResult:
        txn_id = uuid.uuid4().hex
        auth_code = f"auth_{uuid.uuid4().hex[:8]}"
        now = datetime.now(timezone.utc)

        entry = PaymentMockLedger(
            transaction_id=txn_id,
            operation=MockLedgerOperation.release,
            amount_cents=amount_cents,
            from_account=f"hold_{hold_id}",
            to_account=to_account,
            description=f"Release hold {hold_id}",
            status=MockLedgerStatus.settlement_pending,
            authorization_code=auth_code,
            processing_at=now,
            created_at=now,
        )
        await ledger_repo.create_entry(db, entry)

        from app.services import ledger as ledger_svc
        await ledger_svc.record_entries(db, transaction_id=txn_id, entries=[
            {"type": "debit", "account": f"hold_{hold_id}", "amount_cents": amount_cents,
             "description": f"Release hold {hold_id}"},
            {"type": "credit", "account": to_account, "amount_cents": amount_cents,
             "description": f"Release hold {hold_id}"},
        ])

        settlement_delay = await settings_svc.get_int(db, "mock_settlement_delay_seconds")
        if settlement_delay <= 0:
            await ledger_repo.update_entry_status(
                db, entry,
                status=MockLedgerStatus.settled,
                completed_at=datetime.now(timezone.utc),
            )

        return TransferResult(
            transaction_id=txn_id,
            status=entry.status.value,
            authorization_code=auth_code,
        )


class StripePaymentGateway(PaymentGateway):
    """Real Stripe integration — abstract until all methods are implemented.

    To activate: subclass this, implement every method, and update get_gateway().
    """


async def get_gateway(db: AsyncSession) -> PaymentGateway:
    """Factory: returns Stripe when enabled, else Mock."""
    stripe_on = await settings_svc.get_bool(db, "stripe_enabled")
    if stripe_on:
        raise RuntimeError(
            "Stripe is enabled but not yet implemented. "
            "Disable stripe_enabled in admin settings or implement StripePaymentGateway."
        )
    return MockPaymentGateway()
