from datetime import datetime
from pydantic import BaseModel, Field


class DiscountStrategyCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    discount_type: str  # 'pledge_percent' | 'ticket_percent' | 'fixed_cents'
    value: int = Field(..., ge=1)
    target: str = "all"  # 'all' | 'pledgers' | 'non_pledgers'


class DiscountStrategyUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    discount_type: str | None = None
    value: int | None = Field(None, ge=1)
    target: str | None = None


class DiscountStrategyResponse(BaseModel):
    id: int
    organizer_id: int
    name: str
    discount_type: str
    value: int
    target: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
