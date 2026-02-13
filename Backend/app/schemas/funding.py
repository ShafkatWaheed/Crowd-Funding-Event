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
    platform_cut_cents: int = 0
    net_to_organizer_cents: int = 0
    status: str
    is_guest: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class UnpledgeResponse(BaseModel):
    refunded_cents: int
    pledges_refunded: int
    guest_non_refundable_cents: int


class FundingSummaryResponse(BaseModel):
    event_id: int
    total_pledged_cents: int
    total_platform_cut_cents: int = 0
    total_net_to_organizer_cents: int = 0
    backers_count: int
    goal_cents: int | None
    goal_met: bool
    funding_commission_percent: int = 0


class MyPledgeItem(BaseModel):
    """One pledge in the current user's list (which events they've pledged to)."""
    id: int
    event_id: int
    event_title: str
    amount_cents: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}
