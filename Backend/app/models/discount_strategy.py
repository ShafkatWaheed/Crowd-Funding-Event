"""
DiscountStrategy: a reusable discount template owned by an organizer.
Strategies are linked to events via event_discount_strategy_links.
When computing ticket price, the engine reads linked strategies.

auto_apply on the link controls whether the discount is automatically
applied to every eligible customer, or if customers must claim it first.
"""
from datetime import datetime
from sqlalchemy import Boolean, String, Integer, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class DiscountStrategy(Base):
    """Reusable discount template created by organizers (like venues / ticket strategies)."""
    __tablename__ = "discount_strategies"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    organizer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    discount_type: Mapped[str] = mapped_column(String(20), nullable=False)  # 'pledge_percent' | 'ticket_percent'
    value: Mapped[int] = mapped_column(Integer, nullable=False)  # percent 0-100
    target: Mapped[str] = mapped_column(String(16), nullable=False, default="all")  # 'all' | 'pledgers' | 'non_pledgers'
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    organizer = relationship("User", back_populates="discount_strategies")
    event_links = relationship("EventDiscountStrategyLink", back_populates="strategy", cascade="all, delete-orphan")


class EventDiscountStrategyLink(Base):
    """Many-to-many link: attaches a DiscountStrategy to an Event."""
    __tablename__ = "event_discount_strategy_links"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    discount_strategy_id: Mapped[int] = mapped_column(ForeignKey("discount_strategies.id"), nullable=False, index=True)
    auto_apply: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    event = relationship("Event", back_populates="discount_strategy_links")
    strategy = relationship("DiscountStrategy", back_populates="event_links")
    claims = relationship("CustomerDiscountClaim", back_populates="link", cascade="all, delete-orphan")

    __table_args__ = (UniqueConstraint("event_id", "discount_strategy_id", name="uq_event_discount_strategy"),)


class CustomerDiscountClaim(Base):
    """Tracks a customer claiming a non-auto-apply discount on an event."""
    __tablename__ = "customer_discount_claims"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    link_id: Mapped[int] = mapped_column(ForeignKey("event_discount_strategy_links.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    claimed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    link = relationship("EventDiscountStrategyLink", back_populates="claims")
    user = relationship("User")

    __table_args__ = (UniqueConstraint("link_id", "user_id", name="uq_customer_discount_claim"),)
