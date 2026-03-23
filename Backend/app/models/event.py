"""
Event model: status, registration type, funding fields.
"""
import enum
from datetime import datetime
from sqlalchemy import BigInteger, Boolean, String, Text, Integer, Float, DateTime, ForeignKey, Enum, UniqueConstraint, JSON
from sqlalchemy.dialects.postgresql import JSONB
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
    under_review = "under_review"      # auto-transition failed; admin must investigate


class RegistrationType(str, enum.Enum):
    open = "open"
    closed = "closed"


class EventOrganizer(Base):
    """Co-organizers added by the main organizer. Main organizer is events.organizer_id."""
    __tablename__ = "event_organizers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    permission: Mapped[str] = mapped_column(String(10), nullable=False, default="read")  # 'read' | 'full'
    invitation_status: Mapped[str] = mapped_column(String(10), nullable=False, default="accepted")  # 'pending' | 'accepted' | 'declined'
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="event_organizers")
    user = relationship("User", back_populates="event_organizers")

    __table_args__ = (UniqueConstraint("event_id", "user_id", name="uq_event_organizers_event_user"),)


class Event(Base):
    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    organizer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    venue_id: Mapped[int | None] = mapped_column(ForeignKey("venues.id"), nullable=True, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    start_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)  # event date (can be set later)
    end_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    funding_goal_cents: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    funding_end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    min_pledge_cents: Mapped[int] = mapped_column(BigInteger, nullable=False)
    status: Mapped[EventStatus] = mapped_column(Enum(EventStatus), nullable=False, default=EventStatus.draft, index=True)
    registration_type: Mapped[RegistrationType] = mapped_column(Enum(RegistrationType), nullable=False, default=RegistrationType.open)
    max_capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    max_reserved_spots_per_user: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # max spots a pledger can reserve
    common_discount_percent: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # ticket discount for all
    pledge_discount_percent: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # % of user's pledges as discount
    cancellation_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    review_notes: Mapped[str | None] = mapped_column(Text, nullable=True)  # failure message when under_review
    review_log: Mapped[list | None] = mapped_column(JSON, nullable=True, default=list)
    venue_snapshot: Mapped[dict | None] = mapped_column(JSONB, nullable=True)  # frozen venue data for completed/cancelled events
    registration_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # denormalized for trending
    genre: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)
    community_rules: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    posts_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    faq_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    refund_deadline_days: Mapped[int | None] = mapped_column(Integer, nullable=True)  # only set when funding is used; default 20% of funding duration
    event_date_deadline: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)  # deadline to set event date (funding_end + 20% duration)
    ticket_strategy_id: Mapped[int | None] = mapped_column(ForeignKey("ticket_strategies.id"), nullable=True, index=True)
    like_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    dislike_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    pending_extension = mapped_column(JSON, nullable=True)  # {"funding_end_at": ..., "start_time": ..., "end_time": ...}
    pending_cancellation = mapped_column(JSON, nullable=True)  # {"reason": ..., "requested_at": ..., "requested_by": ...}
    terms_accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    payout_frozen: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    # Parking & Transport info
    parking_info: Mapped[str | None] = mapped_column(Text, nullable=True)
    transit_info: Mapped[str | None] = mapped_column(Text, nullable=True)
    rideshare_info: Mapped[str | None] = mapped_column(Text, nullable=True)
    accessibility_info: Mapped[str | None] = mapped_column(Text, nullable=True)
    has_schedule: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    link_funding_to_tiers: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    ticket_selling_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    max_discount_percent: Mapped[int] = mapped_column(Integer, nullable=False, default=100)
    age_restricted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    min_age: Mapped[int] = mapped_column(Integer, nullable=False, default=18)
    # Per-event policy fields (organizer-controlled)
    waitlist_max_size: Mapped[int | None] = mapped_column(Integer, nullable=True)
    waitlist_auto_approve: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    event_max_images: Mapped[int | None] = mapped_column(Integer, nullable=True)
    max_posts_per_day: Mapped[int | None] = mapped_column(Integer, nullable=True)
    max_co_organizers: Mapped[int | None] = mapped_column(Integer, nullable=True)
    refund_deadline_percent: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reserved_spots_release_percent: Mapped[int | None] = mapped_column(Integer, nullable=True)
    release_tier_spot_limits: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    is_private: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    share_token: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True, unique=True)
    # Admin per-event overrides
    admin_override_waitlist_max_size: Mapped[int | None] = mapped_column(Integer, nullable=True)
    admin_override_event_max_images: Mapped[int | None] = mapped_column(Integer, nullable=True)
    admin_override_max_posts_per_day: Mapped[int | None] = mapped_column(Integer, nullable=True)
    admin_override_max_co_organizers: Mapped[int | None] = mapped_column(Integer, nullable=True)
    admin_override_refund_deadline_percent: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    organizer = relationship("User", back_populates="events", foreign_keys=[organizer_id])
    venue = relationship("Venue", back_populates="events")
    fundings = relationship("Funding", back_populates="event", cascade="all, delete-orphan")
    registrations = relationship("Registration", back_populates="event", cascade="all, delete-orphan")
    ticket_tiers = relationship("TicketTier", back_populates="event", cascade="all, delete-orphan")
    user_event_discounts = relationship("UserEventDiscount", back_populates="event", cascade="all, delete-orphan")
    ticket_sales = relationship("TicketSale", back_populates="event", cascade="all, delete-orphan")
    event_organizers = relationship("EventOrganizer", back_populates="event", cascade="all, delete-orphan")
    posts = relationship("EventPost", back_populates="event", cascade="all, delete-orphan")
    images = relationship("EventImage", back_populates="event", cascade="all, delete-orphan")
    ticket_strategy = relationship("TicketStrategy", back_populates="events")
    reactions = relationship("EventReaction", back_populates="event", cascade="all, delete-orphan")
    event_discounts = relationship("EventDiscount", back_populates="event", cascade="all, delete-orphan")
    discount_strategy_links = relationship("EventDiscountStrategyLink", back_populates="event", cascade="all, delete-orphan")
    escrow = relationship("FundEscrow", back_populates="event", uselist=False, cascade="all, delete-orphan")
    milestones = relationship("FundingMilestone", back_populates="event", cascade="all, delete-orphan")
    milestone_snapshots = relationship("FundingMilestoneSnapshot", back_populates="event", cascade="all, delete-orphan")
    early_bird_discounts = relationship("EarlyBirdDiscount", back_populates="event", cascade="all, delete-orphan")
    schedule_items = relationship("EventScheduleItem", back_populates="event", cascade="all, delete-orphan")
    sponsorship_categories = relationship("SponsorshipCategory", back_populates="event", cascade="all, delete-orphan")
    ticket_escrow = relationship("TicketEscrow", back_populates="event", uselist=False, cascade="all, delete-orphan")
    sponsor_escrow = relationship("SponsorEscrow", back_populates="event", uselist=False, cascade="all, delete-orphan")


class EventDiscount(Base):
    """Flexible discount rule attached to an event. Applies to tickets."""
    __tablename__ = "event_discounts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    discount_type: Mapped[str] = mapped_column(String(20), nullable=False)  # 'pledge_percent' | 'ticket_percent' | 'fixed_cents' | 'funding_milestone'
    value: Mapped[int] = mapped_column(Integer, nullable=False)  # percent 0-100 or cents
    target: Mapped[str] = mapped_column(String(16), nullable=False, default="all")  # 'all' | 'pledgers' | 'non_pledgers'
    milestone_percent: Mapped[int | None] = mapped_column(Integer, nullable=True)
    milestone_discount_value: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="event_discounts")


class OrganizerCustomerHistory(Base):
    """Tracks which customers attended events organized by an organizer (auto-populated on ticket scan)."""
    __tablename__ = "organizer_customer_history"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    organizer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False)
    scanned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    organizer = relationship("User", foreign_keys=[organizer_id])
    customer = relationship("User", foreign_keys=[customer_id])
    event = relationship("Event")

    __table_args__ = (UniqueConstraint("organizer_id", "customer_id", "event_id", name="uq_org_cust_event"),)


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
