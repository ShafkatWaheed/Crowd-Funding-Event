"""
Mock payment ledger: logs every simulated payment operation.
Used in mock mode to track charges, transfers, refunds, holds, and releases.
"""
import enum
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Enum, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class MockLedgerOperation(str, enum.Enum):
    charge = "charge"
    transfer = "transfer"
    refund = "refund"
    hold = "hold"
    release = "release"


class MockLedgerStatus(str, enum.Enum):
    pending = "pending"
    processing = "processing"
    completed = "completed"
    failed = "failed"
    settlement_pending = "settlement_pending"
    settled = "settled"


class PaymentMockLedger(Base):
    __tablename__ = "payment_mock_ledger"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    transaction_id: Mapped[str] = mapped_column(
        String(64), unique=True, nullable=False, index=True,
        default=lambda: uuid.uuid4().hex,
    )
    idempotency_key: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)
    operation: Mapped[MockLedgerOperation] = mapped_column(Enum(MockLedgerOperation), nullable=False)
    amount_cents: Mapped[int] = mapped_column(BigInteger, nullable=False)
    from_account: Mapped[str] = mapped_column(String(128), nullable=False)
    to_account: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    status: Mapped[MockLedgerStatus] = mapped_column(
        Enum(MockLedgerStatus), nullable=False, default=MockLedgerStatus.pending,
    )
    authorization_code: Mapped[str | None] = mapped_column(String(32), nullable=True)
    receipt_reference: Mapped[str | None] = mapped_column(String(64), nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(String(64), nullable=True)
    related_type: Mapped[str | None] = mapped_column(String(32), nullable=True)
    related_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    fee_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    processing_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
