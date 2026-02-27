"""
User payment info and organizer bank account models.

UserPaymentInfo: stores tokenized payment method (card on file) for customers.
OrganizerBankAccount: stores encrypted bank details for organizer payouts.
"""
import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, LargeBinary, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class BankVerificationStatus(str, enum.Enum):
    pending = "pending"
    verified = "verified"
    rejected = "rejected"


class UserPaymentInfo(Base):
    """Payment method on file for a user (display-only card info + gateway token)."""
    __tablename__ = "user_payment_info"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, nullable=False, index=True)
    card_holder_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    card_last_four: Mapped[str | None] = mapped_column(String(4), nullable=True)
    card_brand: Mapped[str | None] = mapped_column(String(32), nullable=True)
    billing_address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    payment_method_token: Mapped[str | None] = mapped_column(String(256), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="payment_info")


class OrganizerBankAccount(Base):
    """Encrypted bank account for organizer payouts. Admin sees only status flags."""
    __tablename__ = "organizer_bank_accounts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, nullable=False, index=True)
    bank_name_encrypted: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    account_number_encrypted: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    routing_number_encrypted: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    account_holder_encrypted: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    swift_code_encrypted: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    verification_status: Mapped[BankVerificationStatus] = mapped_column(
        Enum(BankVerificationStatus, name="bankverificationstatus"),
        nullable=False, default=BankVerificationStatus.pending,
    )
    rejection_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    payout_schedule: Mapped[str] = mapped_column(String(16), nullable=False, default="weekly")
    payout_day: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    min_payout_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=2500)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="bank_account")
