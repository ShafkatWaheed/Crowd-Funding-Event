"""
Fund escrow: holds pledged money and releases in stages.
"""
import enum
from datetime import datetime

from sqlalchemy import BigInteger, Integer, String, Text, DateTime, ForeignKey, Enum, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class EscrowStatus(str, enum.Enum):
    holding = "holding"
    partially_released = "partially_released"
    fully_released = "fully_released"
    refunded = "refunded"
    frozen = "frozen"
    waived = "waived"


class FundEscrow(Base):
    """One escrow record per funded event. Tracks staged releases."""
    __tablename__ = "fund_escrows"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), unique=True, nullable=False, index=True)
    total_held_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)

    # Stage 1: Planning (funding goal met + date + venue confirmed)
    stage1_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage1_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Stage 2: Ready (48h before event start)
    stage2_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage2_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Stage 3: Completed (event completed + scan threshold met)
    stage3_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage3_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    stage1_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)
    stage2_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)
    stage3_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)

    status: Mapped[EscrowStatus] = mapped_column(
        Enum(EscrowStatus, name="escrow_status"), nullable=False, default=EscrowStatus.holding
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    releases = relationship("EscrowRelease", back_populates="escrow", cascade="all, delete-orphan")
    event = relationship("Event", back_populates="escrow")


class EscrowRelease(Base):
    """Immutable audit log of each release or refund action."""
    __tablename__ = "escrow_releases"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    escrow_id: Mapped[int] = mapped_column(ForeignKey("fund_escrows.id"), nullable=False, index=True)
    stage: Mapped[int] = mapped_column(Integer, nullable=False)  # 1, 2, or 3
    amount_cents: Mapped[int] = mapped_column(BigInteger, nullable=False)
    released_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    released_by: Mapped[str] = mapped_column(String(32), nullable=False)  # "system" or "admin"
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    release_status: Mapped[str] = mapped_column(String(16), nullable=False, default="completed")

    escrow = relationship("FundEscrow", back_populates="releases")


class TicketEscrow(Base):
    """Escrow for ticket sales revenue. Same 3-stage release as FundEscrow but
    tracks ticket revenue with post-event triggers."""
    __tablename__ = "ticket_escrows"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), unique=True, nullable=False, index=True)
    total_held_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)

    stage1_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage1_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    stage2_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage2_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    stage3_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage3_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    stage1_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)
    stage2_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)
    stage3_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)

    status: Mapped[EscrowStatus] = mapped_column(
        Enum(EscrowStatus, name="escrow_status", create_type=False), nullable=False, default=EscrowStatus.holding,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    event = relationship("Event", back_populates="ticket_escrow")


class SponsorEscrow(Base):
    """Escrow for sponsor payment funds. 3-stage release with sponsor-specific
    triggers (event_live, event_started, days_after_event)."""
    __tablename__ = "sponsor_escrows"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), unique=True, nullable=False, index=True)
    total_held_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)

    stage1_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage1_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    stage2_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage2_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    stage3_released_cents: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    stage3_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    stage1_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)
    stage2_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)
    stage3_auto_release: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", default=True)

    status: Mapped[EscrowStatus] = mapped_column(
        Enum(EscrowStatus, name="escrow_status", create_type=False), nullable=False, default=EscrowStatus.holding,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    event = relationship("Event", back_populates="sponsor_escrow")
