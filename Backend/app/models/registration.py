"""
Registration model: join event (open/closed, capacity).
"""
import enum
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class RegistrationStatus(str, enum.Enum):
    registered = "registered"
    waitlist = "waitlist"
    cancelled = "cancelled"


class Registration(Base):
    __tablename__ = "registrations"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    status: Mapped[RegistrationStatus] = mapped_column(Enum(RegistrationStatus), nullable=False, default=RegistrationStatus.registered)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event", back_populates="registrations")
    user = relationship("User", back_populates="registrations")
