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
    sponsor = "sponsor"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    display_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), nullable=False, default=UserRole.customer)
    terms_accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # relationships
    events = relationship("Event", back_populates="organizer", foreign_keys="Event.organizer_id")
    venues = relationship("Venue", back_populates="organizer", foreign_keys="Venue.organizer_id")
    fundings = relationship("Funding", back_populates="user")
    registrations = relationship("Registration", back_populates="user")
    user_event_discounts = relationship("UserEventDiscount", back_populates="user")
    ticket_sales = relationship("TicketSale", back_populates="user", foreign_keys="TicketSale.user_id")
    ticket_strategies = relationship("TicketStrategy", back_populates="organizer", foreign_keys="TicketStrategy.organizer_id")
    event_organizers = relationship("EventOrganizer", back_populates="user")
    posts = relationship("EventPost", back_populates="user")
    discount_strategies = relationship("DiscountStrategy", back_populates="organizer", foreign_keys="DiscountStrategy.organizer_id")
    sponsor_profile = relationship("SponsorProfile", back_populates="user", uselist=False)
