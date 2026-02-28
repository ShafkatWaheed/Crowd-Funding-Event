"""Funding milestone and early bird discount request/response schemas."""
from datetime import datetime

from pydantic import BaseModel, Field


class MilestoneCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str | None = None
    unlock_percent: int = Field(..., ge=1, le=100)
    benefit_description: str | None = None
    sort_order: int = 0


class MilestoneUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    unlock_percent: int | None = Field(None, ge=1, le=100)
    benefit_description: str | None = None
    sort_order: int | None = None


class MilestoneResponse(BaseModel):
    id: int
    event_id: int
    title: str
    description: str | None = None
    unlock_percent: int
    benefit_description: str | None = None
    sort_order: int = 0
    like_count: int = 0
    dislike_count: int = 0
    is_unlocked: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class MilestoneReactionResponse(BaseModel):
    action: str
    reaction: str
    like_count: int
    dislike_count: int


# ─── Milestone Snapshot Schemas ───


class MilestoneSnapshotResponse(BaseModel):
    id: int
    event_id: int
    milestone_percent: int
    reached_at: datetime
    user_count: int = 0

    model_config = {"from_attributes": True}


# ─── Early Bird Discount Schemas ───


class EarlyBirdDiscountCreate(BaseModel):
    applies_to: str = Field(..., pattern=r"^(funding|tickets)$")
    window_start: str | None = None  # ISO datetime (optional)
    window_end: str  # ISO datetime
    discount_type: str = Field(..., pattern=r"^(percent|fixed_cents)$")
    value: int = Field(..., ge=1)


class EarlyBirdDiscountUpdate(BaseModel):
    window_end: str | None = None
    discount_type: str | None = Field(None, pattern=r"^(percent|fixed_cents)$")
    value: int | None = Field(None, ge=1)


class EarlyBirdDiscountResponse(BaseModel):
    id: int
    event_id: int
    applies_to: str
    window_start: datetime | None = None
    window_end: datetime
    discount_type: str
    value: int
    is_active: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}
