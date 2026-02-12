# User request/response schemas (optional; API may use inline Pydantic models in routes).
from typing import Literal

from pydantic import BaseModel

# Allowed roles when signing up (customer or event organizer).
SignUpRole = Literal["customer", "organizer"]


class MeResponse(BaseModel):
    id: int
    email: str
    display_name: str | None
    phone: str | None
    role: str

    model_config = {"from_attributes": True}


class MeUpdate(BaseModel):
    display_name: str | None = None
    phone: str | None = None


class VerifyBody(BaseModel):
    """Body for POST /auth/verify. For new users, role sets sign-up type."""

    id_token: str
    role: SignUpRole = "customer"


class VerifyResponse(BaseModel):
    user_id: int
    email: str
    display_name: str | None
    role: str
