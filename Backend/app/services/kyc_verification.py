"""
KYC verification service abstraction with mock implementation.

Mirrors the PaymentGateway / MockPaymentGateway pattern from payment_gateway.py.
Factory function get_kyc_service() returns MockKycVerificationService when
kyc_mock_enabled is true; otherwise returns a StripeIdentityKycService stub.
"""
from __future__ import annotations

import asyncio
import os
import random
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.kyc_document import KycDocument, KycDocumentStatus, KycDocumentType
from app.models.notification import NotificationType
from app.models.user import User
from app.repositories.user_repo import user_repo
from app.services import platform_settings as settings_svc

from app.logger import get_logger

logger = get_logger(__name__)

MOCK_FAILURE_REASONS = [
    "document_unreadable",
    "name_mismatch",
    "expired_id",
    "address_mismatch",
    "blurry_selfie",
]

REQUIRED_DOC_TYPES = {KycDocumentType.id_front, KycDocumentType.proof_of_address}


@dataclass
class KycResult:
    status: str  # "verified" | "rejected" | "pending"
    reason: str | None = None
    transaction_id: str | None = None


class KycVerificationService(ABC):
    @abstractmethod
    async def verify_submission(self, db: AsyncSession, *, user_id: int) -> KycResult:
        ...


class MockKycVerificationService(KycVerificationService):
    async def verify_submission(self, db: AsyncSession, *, user_id: int) -> KycResult:
        min_ms = await settings_svc.get_int(db, "mock_kyc_latency_min_ms")
        max_ms = await settings_svc.get_int(db, "mock_kyc_latency_max_ms")
        latency_s = random.randint(min_ms, max(min_ms, max_ms)) / 1000
        await asyncio.sleep(latency_s)

        fail_rate = await settings_svc.get_int(db, "mock_kyc_failure_rate_percent")
        if fail_rate > 0 and random.randint(1, 100) <= fail_rate:
            reason = random.choice(MOCK_FAILURE_REASONS)
            logger.info("MockKYC user=%d REJECTED (%s) after %.1fs", user_id, reason, latency_s)
            return KycResult(
                status="rejected",
                reason=reason,
                transaction_id=f"mock_kyc_{uuid.uuid4().hex[:12]}",
            )

        logger.info("MockKYC user=%d VERIFIED after %.1fs", user_id, latency_s)
        return KycResult(
            status="verified",
            reason=None,
            transaction_id=f"mock_kyc_{uuid.uuid4().hex[:12]}",
        )


class StripeIdentityKycService(KycVerificationService):
    async def verify_submission(self, db: AsyncSession, *, user_id: int) -> KycResult:
        raise NotImplementedError("Stripe Identity not yet integrated")


async def get_kyc_service(db: AsyncSession) -> KycVerificationService:
    if await settings_svc.get_bool(db, "kyc_mock_enabled"):
        return MockKycVerificationService()
    return StripeIdentityKycService()


# ── KYC document management ──


async def list_documents(db: AsyncSession, user_id: int) -> list[KycDocument]:
    return await user_repo.get_kyc_documents(db, user_id)


async def upload_document(
    db: AsyncSession,
    *,
    user_id: int,
    document_type: KycDocumentType,
    file_path: str,
    mime_type: str,
    original_filename: str,
) -> KycDocument:
    # Clean up old file if a document of this type already exists
    existing = await user_repo.get_kyc_document_by_type(db, user_id, document_type.value)
    if existing and os.path.exists(existing.file_path):
        os.remove(existing.file_path)

    return await user_repo.upsert_kyc_document(
        db,
        user_id=user_id,
        document_type=document_type.value,
        file_path=file_path,
        mime_type=mime_type,
        original_filename=original_filename,
    )


async def delete_document(db: AsyncSession, user_id: int, document_id: int) -> None:
    # Fetch the document first to get file_path for cleanup and validate existence
    doc = (
        await db.execute(
            select(KycDocument).where(
                KycDocument.id == document_id,
                KycDocument.user_id == user_id,
            )
        )
    ).scalar_one_or_none()
    if not doc:
        raise ValueError("Document not found")
    if doc.status != KycDocumentStatus.pending:
        raise ValueError("Cannot delete a document that has been reviewed")
    if os.path.exists(doc.file_path):
        os.remove(doc.file_path)
    await user_repo.delete_kyc_document(db, document_id, user_id)


async def submit_for_review(db: AsyncSession, user_id: int) -> KycResult:
    user = await user_repo.get_by_id(db, user_id)
    if not user:
        raise ValueError("User not found")
    if user.kyc_status == "verified":
        return KycResult(status="verified", reason="Already verified")

    docs = await list_documents(db, user_id)
    doc_types = {d.document_type for d in docs}
    missing = REQUIRED_DOC_TYPES - doc_types
    if missing:
        names = ", ".join(t.value for t in missing)
        raise ValueError(f"Missing required documents: {names}")

    await user_repo.update_user(db, user, kyc_status="submitted")

    if await settings_svc.get_bool(db, "kyc_mock_enabled"):
        svc = await get_kyc_service(db)
        result = await svc.verify_submission(db, user_id=user_id)
        now = datetime.now(timezone.utc)
        if result.status == "verified":
            await user_repo.update_user(db, user, kyc_status="verified", kyc_verified_at=now)
            for doc in docs:
                doc.status = KycDocumentStatus.approved
        elif result.status == "rejected":
            await user_repo.update_user(db, user, kyc_status="rejected")
            for doc in docs:
                doc.status = KycDocumentStatus.rejected
                doc.rejection_reason = result.reason
        await db.flush()
        return result

    # Manual review path: status stays "submitted"
    return KycResult(status="pending", reason="Submitted for admin review")


async def admin_verify(
    db: AsyncSession,
    *,
    user_id: int,
    approved: bool,
    rejection_reason: str | None,
    reviewed_by_id: int,
) -> str:
    user = await user_repo.get_by_id(db, user_id)
    if not user:
        raise ValueError("User not found")

    now = datetime.now(timezone.utc)
    docs = await list_documents(db, user_id)

    if approved:
        await user_repo.update_user(db, user, kyc_status="verified", kyc_verified_at=now)
        for doc in docs:
            doc.status = KycDocumentStatus.approved
            doc.reviewed_at = now
            doc.reviewed_by_id = reviewed_by_id
    else:
        await user_repo.update_user(db, user, kyc_status="rejected")
        for doc in docs:
            doc.status = KycDocumentStatus.rejected
            doc.rejection_reason = rejection_reason
            doc.reviewed_at = now
            doc.reviewed_by_id = reviewed_by_id

    await db.flush()

    from app.services import notification_service as notif_svc

    if approved:
        await notif_svc.create_notification(
            db,
            user_id=user_id,
            type=NotificationType.kyc_approved,
            title="Identity Verified",
            message="Your identity verification has been approved. You now have full access.",
            data={"kyc_status": "verified"},
        )
    else:
        await notif_svc.create_notification(
            db,
            user_id=user_id,
            type=NotificationType.kyc_rejected,
            title="Identity Verification Rejected",
            message=f"Your identity verification was rejected: {rejection_reason or 'No reason provided'}. Please re-upload documents.",
            data={"kyc_status": "rejected", "reason": rejection_reason},
        )

    return user.kyc_status


async def list_pending_users(db: AsyncSession) -> list[User]:
    return await user_repo.list_pending_kyc_users(db)
