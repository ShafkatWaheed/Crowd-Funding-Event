"""
Event model: status, registration type, funding fields.
"""
import enum
from datetime import datetime
from sqlalchemy import Boolean, String, Text, Integer, Float, DateTime, ForeignKey, Enum, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class EventStatus(str, enum.Enum):
    draft = "draft"
    pending_approval = "pending_approval"
    approved = "approved"              # published: funding active or no-funding pre-event
    selling_tickets = "selling_tickets" # funding ended, event date known → ticket sales only
    waiting_event_date = "waiting_event_date"  # funding ended, no event date → organizer must set date
    live = "live"                      # event is happening (start_time reached)
    completed = "completed"            # event ended (end_time reached)
    cancelled = "cancelled"


class RegistrationType(str, enum.Enum):
    open = "open"
    closed = "closed"


class EventOrganizer(Base):
    """Co-organizers added by the main organizer. Main organizer is events.organizer_id."""
    __tablename__ = "event_organizers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="event_organizers")
    user = relationship("User", back_populates="event_organizers")

    __table_args__ = (UniqueConstraint("event_id", "user_id", name="uq_event_organizers_event_user"),)


class Event(Base):
    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    organizer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    venue_id: Mapped[int] = mapped_column(ForeignKey("venues.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    start_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)  # event date (can be set later)
    end_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    funding_goal_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    funding_end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    min_pledge_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[EventStatus] = mapped_column(Enum(EventStatus), nullable=False, default=EventStatus.draft, index=True)
    registration_type: Mapped[RegistrationType] = mapped_column(Enum(RegistrationType), nullable=False, default=RegistrationType.open)
    max_capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    common_discount_percent: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # ticket discount for all
    pledge_discount_percent: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # % of user's pledges as discount
    cancellation_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    registration_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # denormalized for trending
    genre: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)
    posts_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    refund_deadline_days: Mapped[int | None] = mapped_column(Integer, nullable=True)  # only set when funding is used; default 20% of funding duration
    event_date_deadline: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)  # deadline to set event date (funding_end + 20% duration)
    ticket_strategy_id: Mapped[int | None] = mapped_column(ForeignKey("ticket_strategies.id"), nullable=True, index=True)
    like_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    dislike_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    organizer = relationship("User", back_populates="events", foreign_keys=[organizer_id])
    venue = relationship("Venue", back_populates="events")
    fundings = relationship("Funding", back_populates="event")
    registrations = relationship("Registration", back_populates="event")
    ticket_tiers = relationship("TicketTier", back_populates="event")
    user_event_discounts = relationship("UserEventDiscount", back_populates="event")
    ticket_sales = relationship("TicketSale", back_populates="event")
    event_organizers = relationship("EventOrganizer", back_populates="event", cascade="all, delete-orphan")
    posts = relationship("EventPost", back_populates="event", cascade="all, delete-orphan")
    images = relationship("EventImage", back_populates="event", cascade="all, delete-orphan")
    ticket_strategy = relationship("TicketStrategy", back_populates="events")
    reactions = relationship("EventReaction", back_populates="event", cascade="all, delete-orphan")


class EventReaction(Base):
    """User like/dislike on an event. One reaction per user per event."""
    __tablename__ = "event_reactions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    reaction: Mapped[str] = mapped_column(String(10), nullable=False)  # 'like' or 'dislike'
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="reactions")
    user = relationship("User")

    __table_args__ = (UniqueConstraint("event_id", "user_id", name="uq_event_reactions_event_user"),)
