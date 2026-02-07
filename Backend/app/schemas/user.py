# User request/response schemas (optional; API may use inline Pydantic models in routes).
from pydantic import BaseModel


class MeResponse(BaseModel):
    id: int
    email: str
    display_name: str | None
    role: str

    model_config = {"from_attributes": True}


class MeUpdate(BaseModel):
    display_name: str | None = None


class VerifyBody(BaseModel):
    id_token: str


class VerifyResponse(BaseModel):
    user_id: int
    email: str
    display_name: str | None
    role: str
