"""
KYC document model for identity verification uploads.
"""
import enum
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class KycDocumentType(str, enum.Enum):
    id_front = "id_front"
    id_back = "id_back"
    proof_of_address = "proof_of_address"
    selfie = "selfie"
    tax_id = "tax_id"


class KycDocumentStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class KycDocument(Base):
    __tablename__ = "kyc_documents"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    document_type: Mapped[KycDocumentType] = mapped_column(Enum(KycDocumentType), nullable=False)
    file_path: Mapped[str] = mapped_column(String(500), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(100), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[KycDocumentStatus] = mapped_column(
        Enum(KycDocumentStatus), nullable=False, default=KycDocumentStatus.pending,
    )
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewed_by_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)

    user = relationship("User", foreign_keys=[user_id], backref="kyc_documents")
    reviewed_by = relationship("User", foreign_keys=[reviewed_by_id])
