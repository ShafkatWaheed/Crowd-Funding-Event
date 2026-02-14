# Funding request/response schemas.
from datetime import datetime

from pydantic import BaseModel


class PledgeBody(BaseModel):
    amount_cents: int
    reserved_spots: int = 0


class PledgeResponse(BaseModel):
    id: int
    event_id: int
    user_id: int
    amount_cents: int
    platform_cut_cents: int = 0
    net_to_organizer_cents: int = 0
    reserved_spots: int = 0
    receipt_number: str | None = None
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
    total_reserved_spots: int = 0


class PledgePreviewResponse(BaseModel):
    """Invoice preview before confirming a pledge."""
    amount_cents: int
    reserved_spots: int
    cost_per_spot_cents: int
    platform_cut_cents: int
    net_to_organizer_cents: int
    funding_commission_percent: int
    available_spots_for_user: int        # how many more spots user can still reserve
    event_total_reserved_spots: int      # current total for the event


class PledgeReceiptResponse(BaseModel):
    """Receipt after a pledge is confirmed."""
    id: int
    receipt_number: str | None = None
    event_id: int
    event_title: str
    user_id: int
    amount_cents: int
    reserved_spots: int = 0
    platform_cut_cents: int = 0
    net_to_organizer_cents: int = 0
    funding_commission_percent: int = 0
    status: str
    created_at: datetime


class MyPledgeItem(BaseModel):
    """One pledge in the current user's list (which events they've pledged to)."""
    id: int
    event_id: int
    event_title: str
    amount_cents: int
    reserved_spots: int = 0
    receipt_number: str | None = None
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}
