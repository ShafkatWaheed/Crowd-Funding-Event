"""
Funding / pledge model.
"""
import enum
from datetime import datetime
from sqlalchemy import BigInteger, Boolean, Integer, String, DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class FundingStatus(str, enum.Enum):
    pledged = "pledged"
    collected = "collected"
    refunded = "refunded"


class Funding(Base):
    __tablename__ = "fundings"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    amount_cents: Mapped[int] = mapped_column(BigInteger, nullable=False)
    platform_cut_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    net_to_organizer_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    status: Mapped[FundingStatus] = mapped_column(Enum(FundingStatus), nullable=False, default=FundingStatus.pledged)
    is_guest: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)  # guest pledges are non-refundable
    reserved_spots: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # spots reserved for future ticket purchase
    receipt_number: Mapped[str | None] = mapped_column(String(32), nullable=True, unique=True, index=True)  # human-readable pledge receipt ID
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="fundings")
    user = relationship("User", back_populates="fundings")
