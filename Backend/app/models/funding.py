"""
Funding / pledge model.
"""
import enum
from datetime import datetime
from sqlalchemy import BigInteger, Boolean, Integer, String, DateTime, ForeignKey, Enum, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class FundingStatus(str, enum.Enum):
    pledged = "pledged"
    collected = "collected"
    refund_processing = "refund_processing"
    refunded = "refunded"
    refund_failed = "refund_failed"


class Funding(Base):
    __tablename__ = "fundings"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    amount_cents: Mapped[int] = mapped_column(BigInteger, nullable=False)
    platform_cut_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    net_to_organizer_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    status: Mapped[FundingStatus] = mapped_column(Enum(FundingStatus), nullable=False, default=FundingStatus.pledged, index=True)
    is_guest: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)  # guest pledges are non-refundable
    reserved_spots: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # spots reserved for future ticket purchase
    is_early_bird: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    receipt_number: Mapped[str | None] = mapped_column(String(32), nullable=True, unique=True, index=True)  # human-readable pledge receipt ID
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="fundings")
    user = relationship("User", back_populates="fundings")
    spot_reservations = relationship("PledgeSpotReservation", back_populates="funding", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_fundings_event_status", "event_id", "status"),
        Index("ix_fundings_event_created", "event_id", "created_at"),
    )


class PledgeSpotReservation(Base):
    """Maps a pledge's reserved spots to specific ticket tiers."""
    __tablename__ = "pledge_spot_reservations"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    funding_id: Mapped[int] = mapped_column(ForeignKey("fundings.id"), nullable=False, index=True)
    ticket_tier_id: Mapped[int] = mapped_column(ForeignKey("ticket_tiers.id"), nullable=False, index=True)
    spots: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    funding = relationship("Funding", back_populates="spot_reservations")
    ticket_tier = relationship("TicketTier")
