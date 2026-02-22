# Ticket tiers, price preview, purchase, and discounts.
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, field_validator, model_validator


class TicketTierCreate(BaseModel):
    name: str
    description: str | None = None
    price_cents: int
    max_reserved_spots: int = 0
    display_order: int = 0

    @field_validator("price_cents")
    @classmethod
    def price_non_negative(cls, v: int) -> int:
        if v < 0:
            raise ValueError("price_cents must be >= 0")
        return v

    @field_validator("max_reserved_spots")
    @classmethod
    def reserved_non_negative(cls, v: int) -> int:
        if v < 0:
            raise ValueError("max_reserved_spots must be >= 0")
        return v


class TicketTierUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    price_cents: int | None = None
    max_reserved_spots: int | None = None
    display_order: int | None = None

    @field_validator("price_cents")
    @classmethod
    def price_non_negative(cls, v: int | None) -> int | None:
        if v is not None and v < 0:
            raise ValueError("price_cents must be >= 0")
        return v

    @field_validator("max_reserved_spots")
    @classmethod
    def reserved_non_negative(cls, v: int | None) -> int | None:
        if v is not None and v < 0:
            raise ValueError("max_reserved_spots must be >= 0")
        return v


class TicketTierResponse(BaseModel):
    id: int
    event_id: int
    name: str
    description: str | None = None
    price_cents: int
    max_reserved_spots: int = 0
    display_order: int

    model_config = {"from_attributes": True}


class TicketPricePreviewResponse(BaseModel):
    tier_price_cents: int
    common_discount_cents: int
    selective_discount_cents: int
    pledge_discount_cents: int
    event_discount_cents: int = 0
    total_discount_cents: int
    final_price_cents: int
    commission_cents: int = 0
    net_to_organizer_cents: int = 0
    ticket_commission_percent: int = 0


class TicketPurchaseBody(BaseModel):
    tier_id: int
    quantity: int = 1  # number of tickets to purchase at once
    extra_perks: str | None = None  # when discount >= price, organizer can set this later or at purchase

    @field_validator("quantity")
    @classmethod
    def quantity_positive(cls, v: int) -> int:
        if v < 1 or v > 10:
            raise ValueError("quantity must be between 1 and 10")
        return v


class TicketSaleResponse(BaseModel):
    id: int
    event_id: int
    user_id: int
    ticket_tier_id: int
    purchase_group_id: str | None = None  # groups multi-ticket purchases
    ticket_code: str  # unique code for QR; customer displays as QR for organizer to scan
    receipt_number: str | None = None  # human-readable receipt ID
    tier_name: str | None = None
    event_title: str | None = None
    attendee_display_name: str | None = None  # name on ticket (holder's display_name or email)
    amount_paid_cents: int
    discount_applied_cents: int
    commission_cents: int = 0
    net_to_organizer_cents: int = 0
    extra_perks: str | None
    status: str
    scanned_at: datetime | None = None  # past scan time when already scanned
    scanned_by_id: int | None = None
    scanned_by_display_name: str | None = None  # who scanned it
    encrypted_qr_payload: str | None = None  # AES-256-GCM encrypted QR data
    created_at: datetime


class TicketReceiptResponse(BaseModel):
    """Full receipt detail for a ticket purchase."""
    sale_id: int
    user_id: int
    receipt_number: str
    ticket_code: str
    status: str
    # Attendee
    attendee_name: str | None = None
    # Event
    event_id: int
    event_title: str
    event_start_time: datetime | None = None
    event_end_time: datetime | None = None
    # Organizer
    organizer_name: str | None = None
    organizer_email: str | None = None
    organizer_phone: str | None = None
    # Venue
    venue_name: str | None = None
    venue_address: str | None = None
    # Tier
    tier_name: str
    tier_price_cents: int
    # Payment
    amount_paid_cents: int
    discount_applied_cents: int
    commission_cents: int = 0
    net_to_organizer_cents: int = 0
    extra_perks: str | None = None
    encrypted_qr_payload: str | None = None  # AES-256-GCM encrypted QR data
    # Timestamps
    purchased_at: datetime
    scanned_at: datetime | None = None


class ScanTicketBody(BaseModel):
    ticket_code: str | None = None          # legacy plaintext ticket code
    encrypted_payload: str | None = None    # AES-256-GCM encrypted QR blob

    @model_validator(mode="after")
    def require_at_least_one(self) -> "ScanTicketBody":
        if not self.ticket_code and not self.encrypted_payload:
            raise ValueError("Provide either ticket_code or encrypted_payload")
        return self


class ScanTicketResponse(BaseModel):
    """Scan result: already_scanned, past scan time and name on ticket are on ticket."""
    already_scanned: bool
    ticket: TicketSaleResponse  # includes scanned_at (past scan time), attendee_display_name (name on ticket)


class TicketSummaryItem(BaseModel):
    """Individual ticket within a purchase group."""
    sale_id: int
    ticket_code: str
    receipt_number: str | None = None
    encrypted_qr_payload: str | None = None
    status: str
    scanned_at: datetime | None = None


class PurchaseGroupReceiptResponse(BaseModel):
    """Aggregated receipt for a multi-ticket purchase group."""
    purchase_group_id: str
    # Event
    event_id: int
    event_title: str
    event_start_time: datetime | None = None
    event_end_time: datetime | None = None
    # Organizer
    organizer_name: str | None = None
    organizer_email: str | None = None
    organizer_phone: str | None = None
    # Venue
    venue_name: str | None = None
    venue_address: str | None = None
    # Attendee
    attendee_name: str | None = None
    # Tier
    tier_name: str
    tier_price_cents: int
    # Aggregated totals
    quantity: int
    total_amount_paid_cents: int
    total_discount_applied_cents: int
    total_commission_cents: int = 0
    total_net_to_organizer_cents: int = 0
    # Tickets
    tickets: list[TicketSummaryItem]
    # Timestamps
    purchased_at: datetime


class TicketSalesStatsResponse(BaseModel):
    """Stats for ticket sales (scanned/total) on an event."""
    total_sold: int
    total_scanned: int


class UserDiscountBody(BaseModel):
    user_id: int
    discount_type: Literal["percent", "fixed_cents"]
    value: int  # 0-100 for percent, or cents for fixed_cents
