# User request/response schemas (optional; API may use inline Pydantic models in routes).
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel

# Allowed roles when signing up.
SignUpRole = Literal["customer", "organizer", "sponsor"]


class MeResponse(BaseModel):
    id: int
    email: str
    display_name: str | None
    phone: str | None
    role: str
    address: str | None = None
    birthday: date | None = None
    years_of_experience: int | None = None
    terms_accepted_at: datetime | None = None
    kyc_status: str = "not_started"
    kyc_verified: bool = False
    kyc_verified_at: datetime | None = None
    # Contact & social presence
    bio: str | None = None
    website_url: str | None = None
    contact_email: str | None = None
    instagram: str | None = None
    twitter: str | None = None
    facebook: str | None = None
    linkedin: str | None = None
    youtube: str | None = None
    tiktok: str | None = None

    model_config = {"from_attributes": True}


class MeUpdate(BaseModel):
    display_name: str | None = None
    phone: str | None = None
    address: str | None = None
    birthday: date | None = None
    years_of_experience: int | None = None
    # Contact & social presence
    bio: str | None = None
    website_url: str | None = None
    contact_email: str | None = None
    instagram: str | None = None
    twitter: str | None = None
    facebook: str | None = None
    linkedin: str | None = None
    youtube: str | None = None
    tiktok: str | None = None


class VerifyBody(BaseModel):
    """Body for POST /auth/verify. For new users, role sets sign-up type. Birthday is required for new signups (all roles) for age verification."""

    id_token: str
    role: SignUpRole = "customer"
    display_name: str | None = None
    terms_accepted_at: datetime | None = None
    birthday: date | None = None  # Required for new users (customer, organizer, sponsor); used for age verification


class VerifyResponse(BaseModel):
    user_id: int
    email: str
    display_name: str | None
    role: str
    terms_accepted_at: datetime | None = None