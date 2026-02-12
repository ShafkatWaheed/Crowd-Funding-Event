"""
Funding / pledge model.
"""
import enum
from datetime import datetime
from sqlalchemy import Boolean, Integer, DateTime, ForeignKey, Enum
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
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[FundingStatus] = mapped_column(Enum(FundingStatus), nullable=False, default=FundingStatus.pledged)
    is_guest: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)  # guest pledges are non-refundable
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="fundings")
    user = relationship("User", back_populates="fundings")
