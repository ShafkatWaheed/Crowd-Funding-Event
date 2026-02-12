# Ticket tiers, price preview, purchase, and discounts.
from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class TicketTierCreate(BaseModel):
    name: str
    description: str | None = None
    price_cents: int
    display_order: int = 0


class TicketTierUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    price_cents: int | None = None
    display_order: int | None = None


class TicketTierResponse(BaseModel):
    id: int
    event_id: int
    name: str
    description: str | None = None
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
    ticket_code: str  # unique code for QR; customer displays as QR for organizer to scan
    tier_name: str | None = None
    event_title: str | None = None
    attendee_display_name: str | None = None  # name on ticket (holder's display_name or email)
    amount_paid_cents: int
    discount_applied_cents: int
    extra_perks: str | None
    status: str
    scanned_at: datetime | None = None  # past scan time when already scanned
    scanned_by_id: int | None = None
    scanned_by_display_name: str | None = None  # who scanned it
    created_at: datetime


class ScanTicketBody(BaseModel):
    ticket_code: str


class ScanTicketResponse(BaseModel):
    """Scan result: already_scanned, past scan time and name on ticket are on ticket."""
    already_scanned: bool
    ticket: TicketSaleResponse  # includes scanned_at (past scan time), attendee_display_name (name on ticket)


class UserDiscountBody(BaseModel):
    user_id: int
    discount_type: Literal["percent", "fixed_cents"]
    value: int  # 0-100 for percent, or cents for fixed_cents
