"""
Ticket tiers, sales, and per-user/event discounts.
"""
import enum
from datetime import datetime

from sqlalchemy import Integer, String, Text, DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TicketSaleStatus(str, enum.Enum):
    purchased = "purchased"
    cancelled = "cancelled"


class TicketTier(Base):
    """Organizer-defined tier (e.g. Platinum, Diamond) with a price."""
    __tablename__ = "ticket_tiers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(64), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)  # what this tier provides
    price_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    event = relationship("Event", back_populates="ticket_tiers")
    ticket_sales = relationship("TicketSale", back_populates="ticket_tier", cascade="all, delete-orphan")


class UserEventDiscount(Base):
    """Selective discount for a specific user on an event (organizer-set)."""
    __tablename__ = "user_event_discounts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    discount_type: Mapped[str] = mapped_column(String(16), nullable=False)  # 'percent' | 'fixed_cents'
    value: Mapped[int] = mapped_column(Integer, nullable=False)  # percent 0-100 or cents

    event = relationship("Event", back_populates="user_event_discounts")
    user = relationship("User", back_populates="user_event_discounts")


class TicketSale(Base):
    """A ticket sold to a registered user. Discount and extra_perks applied at purchase."""
    __tablename__ = "ticket_sales"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    ticket_tier_id: Mapped[int] = mapped_column(ForeignKey("ticket_tiers.id"), nullable=False, index=True)
    ticket_code: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)  # unique code for QR
    amount_paid_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    discount_applied_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    commission_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # platform commission
    net_to_organizer_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # amount_paid - commission
    extra_perks: Mapped[str | None] = mapped_column(Text, nullable=True)  # when discount > price
    status: Mapped[TicketSaleStatus] = mapped_column(Enum(TicketSaleStatus), nullable=False, default=TicketSaleStatus.purchased)
    scanned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    scanned_by_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="ticket_sales")
    user = relationship("User", back_populates="ticket_sales", foreign_keys=[user_id])
    ticket_tier = relationship("TicketTier", back_populates="ticket_sales")
    scanned_by = relationship("User", foreign_keys=[scanned_by_id])
