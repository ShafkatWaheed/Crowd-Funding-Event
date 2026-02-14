# Ticket Strategy schemas.
from datetime import datetime
from pydantic import BaseModel


class TicketStrategyTierInput(BaseModel):
    name: str           # e.g. "Platinum", "Diamond", "General"
    description: str | None = None  # what this tier provides
    price_cents: int    # price in cents
    display_order: int = 0


class TicketStrategyCreate(BaseModel):
    name: str           # e.g. "Concert Standard", "Gala VIP"
    tiers: list[TicketStrategyTierInput]


class TicketStrategyUpdate(BaseModel):
    name: str | None = None
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
