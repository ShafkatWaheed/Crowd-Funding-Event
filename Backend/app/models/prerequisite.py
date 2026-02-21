"""Sponsorship category prerequisites and document uploads."""
import enum
from datetime import datetime
from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class UploadStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class CategoryPrerequisite(Base):
    __tablename__ = "category_prerequisites"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("sponsorship_categories.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_required: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    requires_document: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    category = relationship("SponsorshipCategory")
    uploads = relationship("BidPrerequisiteUpload", back_populates="prerequisite")


class BidPrerequisiteUpload(Base):
    __tablename__ = "bid_prerequisite_uploads"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    bid_id: Mapped[int] = mapped_column(ForeignKey("sponsor_bids.id"), nullable=False, index=True)
    prerequisite_id: Mapped[int] = mapped_column(ForeignKey("category_prerequisites.id"), nullable=False)
    file_url: Mapped[str] = mapped_column(String(500), nullable=False)
    status: Mapped[UploadStatus] = mapped_column(Enum(UploadStatus), default=UploadStatus.pending, nullable=False)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewer_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    bid = relationship("SponsorBid")
    prerequisite = relationship("CategoryPrerequisite", back_populates="uploads")
