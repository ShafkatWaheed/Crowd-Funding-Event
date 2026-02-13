from datetime import datetime
from pydantic import BaseModel


class DiscountStrategyCreate(BaseModel):
    name: str
    discount_type: str  # 'pledge_percent' | 'ticket_percent' | 'fixed_cents'
    value: int
    target: str = "all"  # 'all' | 'pledgers' | 'non_pledgers'


class DiscountStrategyUpdate(BaseModel):
    name: str | None = None
    discount_type: str | None = None
    value: int | None = None
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
