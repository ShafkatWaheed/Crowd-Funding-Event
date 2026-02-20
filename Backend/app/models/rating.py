"""Rating model for multi-directional reviews."""
import enum
from datetime import datetime
from sqlalchemy import DateTime, Enum, ForeignKey, Integer, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class RatingDirection(str, enum.Enum):
    customer_to_event = "customer_to_event"
    customer_to_organizer = "customer_to_organizer"
    organizer_to_sponsor = "organizer_to_sponsor"
    sponsor_to_organizer = "sponsor_to_organizer"


class Rating(Base):
    __tablename__ = "ratings"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    rater_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    rated_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    direction: Mapped[RatingDirection] = mapped_column(Enum(RatingDirection), nullable=False)
    stars: Mapped[int] = mapped_column(Integer, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    rater = relationship("User", foreign_keys=[rater_user_id])
    rated_user = relationship("User", foreign_keys=[rated_user_id])
    event = relationship("Event")

    __table_args__ = (
        UniqueConstraint("rater_user_id", "event_id", "direction", name="uq_ratings_rater_event_direction"),
    )
