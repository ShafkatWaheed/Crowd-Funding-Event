"""
User model and role enum.
"""
import enum
from datetime import datetime
from sqlalchemy import String, Enum, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class UserRole(str, enum.Enum):
    admin = "admin"
    organizer = "organizer"
    customer = "customer"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    display_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), nullable=False, default=UserRole.customer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # relationships
    events = relationship("Event", back_populates="organizer", foreign_keys="Event.organizer_id")
    venues = relationship("Venue", back_populates="organizer", foreign_keys="Venue.organizer_id")
    fundings = relationship("Funding", back_populates="user")
    registrations = relationship("Registration", back_populates="user")
    user_event_discounts = relationship("UserEventDiscount", back_populates="user")
    ticket_sales = relationship("TicketSale", back_populates="user")
