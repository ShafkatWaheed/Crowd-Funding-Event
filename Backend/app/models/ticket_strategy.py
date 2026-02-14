"""
Ticket Strategy: a reusable ticketing template owned by an organizer.
Each strategy has named tiers (e.g. Platinum, Diamond) with prices.
Strategies are linked to events — when an event uses a strategy,
TicketTier rows are copied from the strategy tiers on event creation.
"""
from datetime import datetime
from sqlalchemy import String, Text, Integer, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TicketStrategy(Base):
    """Reusable ticketing template created by organizers (like venues)."""
    __tablename__ = "ticket_strategies"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    organizer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)  # e.g. "Concert Standard", "Gala VIP"
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    organizer = relationship("User", back_populates="ticket_strategies")
    tiers = relationship("TicketStrategyTier", back_populates="strategy", cascade="all, delete-orphan",
                         order_by="TicketStrategyTier.display_order")
    events = relationship("Event", back_populates="ticket_strategy")


class TicketStrategyTier(Base):
    """A tier within a ticket strategy template."""
    __tablename__ = "ticket_strategy_tiers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    strategy_id: Mapped[int] = mapped_column(ForeignKey("ticket_strategies.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(64), nullable=False)  # e.g. "Platinum", "Diamond", "General"
    description: Mapped[str | None] = mapped_column(Text, nullable=True)  # what this tier provides
    price_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    strategy = relationship("TicketStrategy", back_populates="tiers")
