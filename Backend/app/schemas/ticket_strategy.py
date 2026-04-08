# Ticket Strategy schemas.
from datetime import datetime
from pydantic import BaseModel, Field


class TicketStrategyTierInput(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str | None = Field(None, max_length=2000)
    price_cents: int = Field(..., ge=0)  # 0 = free tier
    display_order: int = 0


class TicketStrategyCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    tiers: list[TicketStrategyTierInput]


class TicketStrategyUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    tiers: list[TicketStrategyTierInput] | None = None  # full replace of tiers


class TicketStrategyTierResponse(BaseModel):
    id: int
    name: str
    description: str | None = None
    price_cents: int
    display_order: int

    model_config = {"from_attributes": True}


class TicketStrategyResponse(BaseModel):
    id: int
    organizer_id: int
    name: str
    tiers: list[TicketStrategyTierResponse]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
