"""
Sponsor marketplace models: profiles, categories, bids, payments, tickets.
"""
import enum
from datetime import datetime
from sqlalchemy import String, Text, Integer, DateTime, ForeignKey, Index, Enum, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class SponsorProfile(Base):
    __tablename__ = "sponsor_profiles"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, nullable=False)
    company_name: Mapped[str] = mapped_column(String(200), nullable=False)
    contact_name: Mapped[str] = mapped_column(String(200), nullable=False)
    profession: Mapped[str] = mapped_column(String(100), nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    website_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="sponsor_profile")


class SponsorshipCategory(Base):
    __tablename__ = "sponsorship_categories"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    total_spots: Mapped[int] = mapped_column(Integer, nullable=False)
    filled_spots: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    min_bid_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="sponsorship_categories")
    bids = relationship("SponsorBid", back_populates="category", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_sponsorship_categories_event_sort", "event_id", "sort_order"),
    )


class BidStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    withdrawn = "withdrawn"
    paid = "paid"


class SponsorBid(Base):
    __tablename__ = "sponsor_bids"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("sponsorship_categories.id"), nullable=False)
    sponsor_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    proposal_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[BidStatus] = mapped_column(Enum(BidStatus), nullable=False, default=BidStatus.pending)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    category = relationship("SponsorshipCategory", back_populates="bids")
    sponsor = relationship("User")
    payment = relationship("SponsorPayment", back_populates="bid", uselist=False)


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    completed = "completed"
    refunded = "refunded"


class SponsorPayment(Base):
    __tablename__ = "sponsor_payments"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    bid_id: Mapped[int] = mapped_column(ForeignKey("sponsor_bids.id"), unique=True, nullable=False)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    platform_cut_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    net_to_organizer_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    receipt_number: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[PaymentStatus] = mapped_column(Enum(PaymentStatus), nullable=False, default=PaymentStatus.completed)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    bid = relationship("SponsorBid", back_populates="payment")


class SponsorTicket(Base):
    __tablename__ = "sponsor_tickets"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False)
    sponsor_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    qr_data_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    receipt_number: Mapped[str] = mapped_column(String(100), nullable=False)
    scanned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    scan_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event")
    sponsor = relationship("User")

    __table_args__ = (
        UniqueConstraint("event_id", "sponsor_user_id", name="uq_sponsor_tickets_event_user"),
    )
