"""
Bookmark model — users can bookmark events for quick access.
"""
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Bookmark(Base):
    __tablename__ = "bookmarks"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    event_id: Mapped[int] = mapped_column(Integer, ForeignKey("events.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    user = relationship("User")
    event = relationship("Event")

    __table_args__ = (
        UniqueConstraint("user_id", "event_id", name="uq_bookmarks_user_event"),
    )
