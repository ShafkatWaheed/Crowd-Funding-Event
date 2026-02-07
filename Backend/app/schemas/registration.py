# Registration request/response schemas.
from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class RegistrationResponse(BaseModel):
    id: int
    event_id: int
    user_id: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class RegistrationDecisionBody(BaseModel):
    action: Literal["approve", "reject"]
