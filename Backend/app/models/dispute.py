"""
Dispute/chargeback tracking. Created from payment gateway webhooks or admin simulation.
"""
import enum
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class DisputeStatus(str, enum.Enum):
    open = "open"
    evidence_submitted = "evidence_submitted"
    won = "won"
    lost = "lost"


class Dispute(Base):
    __tablename__ = "disputes"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    stripe_dispute_id: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True)
    transaction_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    event_id: Mapped[int | None] = mapped_column(ForeignKey("events.id"), nullable=True, index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    fee_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=1500)
    reason: Mapped[str] = mapped_column(String(64), nullable=False, default="product_not_received")
    status: Mapped[DisputeStatus] = mapped_column(
        Enum(DisputeStatus), nullable=False, default=DisputeStatus.open,
    )
    evidence_submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    outcome_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event")
    user = relationship("User")
