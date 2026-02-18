# User request/response schemas (optional; API may use inline Pydantic models in routes).
from datetime import datetime
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
    terms_accepted_at: datetime | None = None

    model_config = {"from_attributes": True}


class MeUpdate(BaseModel):
    display_name: str | None = None
    phone: str | None = None


class VerifyBody(BaseModel):
    """Body for POST /auth/verify. For new users, role sets sign-up type."""

    id_token: str
    role: SignUpRole = "customer"
    display_name: str | None = None
    terms_accepted_at: datetime | None = None


class VerifyResponse(BaseModel):
    user_id: int
    email: str
    display_name: str | None
    role: str
    terms_accepted_at: datetime | None = None