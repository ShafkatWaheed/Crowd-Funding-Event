"""
Funding milestones: percentage-based unlock goals with per-milestone reactions.
"""
from datetime import datetime
from sqlalchemy import String, Text, Integer, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class FundingMilestone(Base):
    """A funding milestone on an event. Unlocks when pledged % >= unlock_percent."""
    __tablename__ = "funding_milestones"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    unlock_percent: Mapped[int] = mapped_column(Integer, nullable=False)
    benefit_description: Mapped[str | None] = mapped_column(Text, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    like_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    dislike_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="milestones")
    reactions = relationship("MilestoneReaction", back_populates="milestone", cascade="all, delete-orphan")


class MilestoneReaction(Base):
    """User like/dislike on a milestone. One reaction per user per milestone."""
    __tablename__ = "milestone_reactions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    milestone_id: Mapped[int] = mapped_column(ForeignKey("funding_milestones.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    reaction: Mapped[str] = mapped_column(String(10), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    milestone = relationship("FundingMilestone", back_populates="reactions")
    user = relationship("User")

    __table_args__ = (UniqueConstraint("milestone_id", "user_id", name="uq_milestone_reactions_milestone_user"),)
