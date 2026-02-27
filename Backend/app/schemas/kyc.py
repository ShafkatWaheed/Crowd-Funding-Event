"""
KYC (Know Your Customer) schemas.
"""
from datetime import datetime

from pydantic import BaseModel


class KycDocumentResponse(BaseModel):
    id: int
    document_type: str
    file_url: str
    mime_type: str
    original_filename: str
    status: str
    rejection_reason: str | None = None
    submitted_at: datetime

    model_config = {"from_attributes": True}


class KycStatusResponse(BaseModel):
    kyc_status: str
    kyc_verified: bool
    kyc_verified_at: datetime | None = None
    kyc_required_for_role: bool
    documents: list[KycDocumentResponse] = []


class KycSubmitResponse(BaseModel):
    kyc_status: str
    message: str


class KycVerifyBody(BaseModel):
    approved: bool
    rejection_reason: str | None = None


class KycPendingUser(BaseModel):
    user_id: int
    email: str
    display_name: str | None
    role: str
    kyc_status: str
    submitted_at: datetime | None = None
    document_count: int = 0
