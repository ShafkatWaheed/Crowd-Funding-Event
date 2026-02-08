# Ticket tiers, price preview, purchase, and discounts.
from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class TicketTierCreate(BaseModel):
    name: str
    price_cents: int
    display_order: int = 0


class TicketTierUpdate(BaseModel):
    name: str | None = None
    price_cents: int | None = None
    display_order: int | None = None


class TicketTierResponse(BaseModel):
    id: int
    event_id: int
    name: str
    price_cents: int
    display_order: int

    model_config = {"from_attributes": True}


class TicketPricePreviewResponse(BaseModel):
    tier_price_cents: int
    common_discount_cents: int
    selective_discount_cents: int
    pledge_discount_cents: int
    total_discount_cents: int
    final_price_cents: int


class TicketPurchaseBody(BaseModel):
    tier_id: int
    extra_perks: str | None = None  # when discount >= price, organizer can set this later or at purchase


class TicketSaleResponse(BaseModel):
    id: int
    event_id: int
    user_id: int
    ticket_tier_id: int
    tier_name: str | None = None
    event_title: str | None = None
    amount_paid_cents: int
    discount_applied_cents: int
    extra_perks: str | None
    status: str
    created_at: datetime


class UserDiscountBody(BaseModel):
    user_id: int
    discount_type: Literal["percent", "fixed_cents"]
    value: int  # 0-100 for percent, or cents for fixed_cents
