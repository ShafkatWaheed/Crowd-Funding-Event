"""
Sponsor marketplace models: profiles, categories, bids, payments, tickets.
"""
import enum
from datetime import datetime
from sqlalchemy import Boolean, Float, String, Text, Integer, DateTime, ForeignKey, Index, Enum, UniqueConstraint
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
    event_id: Mapped[int | None] = mapped_column(ForeignKey("events.id"), nullable=True)
    organizer_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    is_template: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    total_spots: Mapped[int] = mapped_column(Integer, nullable=False)
    filled_spots: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    min_bid_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="sponsorship_categories")
    organizer = relationship("User", foreign_keys=[organizer_id])
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
    category_id: Mapped[int] = mapped_column(ForeignKey("sponsorship_categories.id"), nullable=False, index=True)
    sponsor_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    proposal_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[BidStatus] = mapped_column(Enum(BidStatus), nullable=False, default=BidStatus.pending, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # Chat metadata (content lives in Redis Streams, not PostgreSQL)
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    unread_count_organizer: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    unread_count_sponsor: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    category = relationship("SponsorshipCategory", back_populates="bids")
    sponsor = relationship("User")
    payment = relationship("SponsorPayment", back_populates="bid", uselist=False)


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    completed = "completed"
    refund_processing = "refund_processing"
    refunded = "refunded"
    refund_failed = "refund_failed"


class SponsorPayment(Base):
    __tablename__ = "sponsor_payments"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    bid_id: Mapped[int] = mapped_column(ForeignKey("sponsor_bids.id"), unique=True, nullable=False)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    platform_cut_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    net_to_organizer_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    receipt_number: Mapped[str] = mapped_column(String(100), nullable=False)
    subtotal_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    tax_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    tax_rate: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    gateway_transaction_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    gateway_auth_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    stripe_payment_intent_id: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True)
    gateway_refund_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    status: Mapped[PaymentStatus] = mapped_column(Enum(PaymentStatus), nullable=False, default=PaymentStatus.completed, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    bid = relationship("SponsorBid", back_populates="payment")


class SponsorTicket(Base):
    __tablename__ = "sponsor_tickets"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    sponsor_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    qr_data_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    receipt_number: Mapped[str] = mapped_column(String(100), nullable=False)
    scanned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    scan_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event")
    sponsor = relationship("User")
    delegates = relationship("SponsorDelegate", back_populates="ticket", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("event_id", "sponsor_user_id", name="uq_sponsor_tickets_event_user"),
    )


class SponsorDelegate(Base):
    __tablename__ = "sponsor_delegates"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    sponsor_ticket_id: Mapped[int] = mapped_column(ForeignKey("sponsor_tickets.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    checked_in: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    checked_in_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    ticket = relationship("SponsorTicket", back_populates="delegates")

    __table_args__ = (
        UniqueConstraint("sponsor_ticket_id", "email", name="uq_sponsor_delegate_ticket_email"),
    )
