"""
In-app notification model.
"""
import enum
from datetime import datetime
from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class NotificationType(str, enum.Enum):
    # Registration
    registration_confirmed = "registration_confirmed"
    registration_waitlisted = "registration_waitlisted"
    waitlist_approved = "waitlist_approved"
    waitlist_rejected = "waitlist_rejected"

    # Funding / Pledges
    pledge_confirmed = "pledge_confirmed"
    funding_goal_reached = "funding_goal_reached"
    milestone_reached = "milestone_reached"

    # Tickets
    ticket_purchased = "ticket_purchased"
    ticket_waitlist_approved = "ticket_waitlist_approved"
    ticket_waitlist_rejected = "ticket_waitlist_rejected"

    # Refunds
    refund_issued = "refund_issued"

    # Event lifecycle
    event_status_changed = "event_status_changed"
    event_approved = "event_approved"
    event_rejected = "event_rejected"
    event_cancelled = "event_cancelled"
    event_updated = "event_updated"
    schedule_updated = "schedule_updated"

    # Sponsor
    bid_received = "bid_received"
    bid_accepted = "bid_accepted"
    bid_rejected = "bid_rejected"
    sponsor_payment_received = "sponsor_payment_received"
    sponsor_refunded = "sponsor_refunded"
    sponsor_ticket_generated = "sponsor_ticket_generated"

    # Social (used by Feature 5)
    new_rating_received = "new_rating_received"

    # Bookmarks (used by Feature 6)
    bookmarked_event_update = "bookmarked_event_update"

    # Admin review
    event_under_review = "event_under_review"


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    type: Mapped[NotificationType] = mapped_column(Enum(NotificationType), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    data: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    user = relationship("User")
