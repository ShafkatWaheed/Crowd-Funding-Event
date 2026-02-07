"""
Event model: status, registration type, funding fields.
"""
import enum
from datetime import datetime
from sqlalchemy import String, Text, Integer, Float, DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class EventStatus(str, enum.Enum):
    draft = "draft"
    pending_approval = "pending_approval"
    approved = "approved"
    live = "live"
    ended = "ended"
    cancelled = "cancelled"


class RegistrationType(str, enum.Enum):
    open = "open"
    closed = "closed"


class Event(Base):
    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    organizer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    venue_id: Mapped[int] = mapped_column(ForeignKey("venues.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    funding_goal_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    funding_end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[EventStatus] = mapped_column(Enum(EventStatus), nullable=False, default=EventStatus.draft, index=True)
    registration_type: Mapped[RegistrationType] = mapped_column(Enum(RegistrationType), nullable=False, default=RegistrationType.open)
    max_capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    organizer = relationship("User", back_populates="events", foreign_keys=[organizer_id])
    venue = relationship("Venue", back_populates="events")
    fundings = relationship("Funding", back_populates="event")
    registrations = relationship("Registration", back_populates="event")
