"""
User model and role enum.
"""
import enum
from datetime import date, datetime
from sqlalchemy import Boolean, Date, Integer, String, Text, Enum, DateTime
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
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    birthday: Mapped[date | None] = mapped_column(Date, nullable=True)
    years_of_experience: Mapped[int | None] = mapped_column(Integer, nullable=True)
    terms_accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    kyc_status: Mapped[str] = mapped_column(String(20), nullable=False, default="not_started")
    kyc_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    stripe_customer_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    stripe_connect_account_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    # Contact & social presence (organizer / sponsor public profile)
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    website_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    contact_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    instagram: Mapped[str | None] = mapped_column(String(100), nullable=True)
    twitter: Mapped[str | None] = mapped_column(String(100), nullable=True)
    facebook: Mapped[str | None] = mapped_column(String(255), nullable=True)
    linkedin: Mapped[str | None] = mapped_column(String(255), nullable=True)
    youtube: Mapped[str | None] = mapped_column(String(255), nullable=True)
    tiktok: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    @property
    def kyc_verified(self) -> bool:
        return self.kyc_status == "verified"

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
    payment_info = relationship("UserPaymentInfo", back_populates="user", uselist=False)
    bank_account = relationship("OrganizerBankAccount", back_populates="user", uselist=False)
