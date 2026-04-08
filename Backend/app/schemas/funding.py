# Funding request/response schemas.
from datetime import datetime

from pydantic import BaseModel, Field


class TierReservation(BaseModel):
    tier_id: int
    spots: int = Field(..., ge=1)


class PledgeBody(BaseModel):
    amount_cents: int = Field(..., ge=1)
    reserved_spots: int = Field(0, ge=0)
    tier_reservations: list[TierReservation] | None = None


class TierReservationResponse(BaseModel):
    tier_id: int
    tier_name: str | None = None
    spots: int


class PledgeResponse(BaseModel):
    id: int
    event_id: int
    user_id: int
    amount_cents: int
    platform_cut_cents: int = 0
    net_to_organizer_cents: int = 0
    reserved_spots: int = 0
    tier_reservations: list[TierReservationResponse] = []
    receipt_number: str | None = None
    status: str
    is_guest: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class UnpledgeResponse(BaseModel):
    refunded_cents: int
    pledges_refunded: int
    guest_non_refundable_cents: int
    status: str = "completed"  # "refund_processing" | "completed"


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


class TierAvailability(BaseModel):
    tier_id: int
    tier_name: str
    price_cents: int
    max_reserved_spots: int
    reserved_so_far: int
    available: int


class PledgePreviewResponse(BaseModel):
    """Invoice preview before confirming a pledge."""
    amount_cents: int
    reserved_spots: int
    cost_per_spot_cents: int
    platform_cut_cents: int
    net_to_organizer_cents: int
    funding_commission_percent: int
    available_spots_for_user: int
    event_total_reserved_spots: int
    link_funding_to_tiers: bool = False
    tier_availability: list[TierAvailability] = []


class PledgeReceiptResponse(BaseModel):
    """Receipt after a pledge is confirmed."""
    id: int
    receipt_number: str | None = None
    event_id: int
    event_title: str
    user_id: int
    backer_name: str | None = None
    amount_cents: int
    reserved_spots: int = 0
    tier_reservations: list[TierReservationResponse] = []
    platform_cut_cents: int = 0
    net_to_organizer_cents: int = 0
    funding_commission_percent: int = 0
    subtotal_cents: int = 0
    tax_cents: int = 0
    tax_rate: float = 0.0
    status: str
    is_guest: bool = False
    created_at: datetime


class MyPledgeItem(BaseModel):
    """One pledge in the current user's list (which events they've pledged to)."""
    id: int
    event_id: int
    event_title: str
    amount_cents: int
    reserved_spots: int = 0
    tier_reservations: list[TierReservationResponse] = []
    receipt_number: str | None = None
    status: str
    is_guest: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class OrganizerPledgeItem(BaseModel):
    """A pledge made to one of the organizer's events."""
    id: int
    event_id: int
    event_title: str
    backer_name: str
    amount_cents: int
    net_to_organizer_cents: int = 0
    reserved_spots: int = 0
    receipt_number: str | None = None
    status: str
    is_guest: bool = False
    created_at: datetime
