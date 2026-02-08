# Funding request/response schemas.
from datetime import datetime

from pydantic import BaseModel


class PledgeBody(BaseModel):
    amount_cents: int


class PledgeResponse(BaseModel):
    id: int
    event_id: int
    user_id: int
    amount_cents: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class FundingSummaryResponse(BaseModel):
    event_id: int
    total_pledged_cents: int
    backers_count: int
    goal_cents: int | None
    goal_met: bool


class MyPledgeItem(BaseModel):
    """One pledge in the current user's list (which events they've pledged to)."""
    id: int
    event_id: int
    event_title: str
    amount_cents: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}
