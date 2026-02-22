"""
Funding milestones: percentage-based unlock goals with per-milestone reactions,
milestone discount snapshots, and early bird discounts.
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


class FundingMilestoneSnapshot(Base):
    """Snapshot of pledgers when a funding milestone is reached."""
    __tablename__ = "funding_milestone_snapshots"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    milestone_percent: Mapped[int] = mapped_column(Integer, nullable=False)
    reached_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="milestone_snapshots")
    users = relationship("FundingMilestoneUser", back_populates="snapshot", cascade="all, delete-orphan")


class FundingMilestoneUser(Base):
    """A user who was pledged at the time a milestone was reached."""
    __tablename__ = "funding_milestone_users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    snapshot_id: Mapped[int] = mapped_column(
        ForeignKey("funding_milestone_snapshots.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)

    snapshot = relationship("FundingMilestoneSnapshot", back_populates="users")
    user = relationship("User")


class EarlyBirdDiscount(Base):
    """Time-window discount: early pledgers or early ticket buyers get a discount."""
    __tablename__ = "early_bird_discounts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    applies_to: Mapped[str] = mapped_column(String(20), nullable=False)  # 'funding' | 'tickets'
    window_start: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    window_end: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    discount_type: Mapped[str] = mapped_column(String(20), nullable=False)  # 'percent' | 'fixed_cents'
    value: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="early_bird_discounts")
