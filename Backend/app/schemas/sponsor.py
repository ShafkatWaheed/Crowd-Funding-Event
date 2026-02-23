"""
Sponsor marketplace Pydantic schemas.
"""
from pydantic import BaseModel, ConfigDict


# ── Sponsor Profile ──

class SponsorProfileCreate(BaseModel):
    company_name: str
    contact_name: str
    profession: str
    logo_url: str | None = None
    description: str | None = None
    website_url: str | None = None


class SponsorProfileUpdate(BaseModel):
    company_name: str | None = None
    contact_name: str | None = None
    profession: str | None = None
    logo_url: str | None = None
    description: str | None = None
    website_url: str | None = None


class SponsorProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    company_name: str
    contact_name: str
    profession: str
    logo_url: str | None = None
    description: str | None = None
    website_url: str | None = None


# ── Sponsorship Categories ──

class CategoryCreate(BaseModel):
    name: str
    description: str | None = None
    image_url: str | None = None
    total_spots: int
    min_bid_cents: int
    sort_order: int = 0


class CategoryUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    image_url: str | None = None
    total_spots: int | None = None
    min_bid_cents: int | None = None
    sort_order: int | None = None


class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    event_id: int | None = None
    organizer_id: int | None = None
    is_template: bool = False
    name: str
    description: str | None = None
    image_url: str | None = None
    total_spots: int
    filled_spots: int = 0
    min_bid_cents: int
    sort_order: int = 0
    bid_count: int = 0
    bid_amounts: list[int] = []


# ── Sponsor Bids ──

class BidCreate(BaseModel):
    amount_cents: int
    proposal_text: str | None = None


class BidUpdate(BaseModel):
    amount_cents: int | None = None
    proposal_text: str | None = None


class BidResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    category_id: int
    sponsor_user_id: int
    amount_cents: int
    proposal_text: str | None = None
    status: str
    sponsor_profile: SponsorProfileResponse | None = None


# ── Payments ──

class PaymentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    bid_id: int
    amount_cents: int
    platform_cut_cents: int
    net_to_organizer_cents: int
    receipt_number: str
    status: str


# ── Sponsor Tickets ──

class SponsorTicketPrereqInfo(BaseModel):
    id: int
    name: str
    is_required: bool
    upload_status: str | None = None

class SponsorTicketCategoryInfo(BaseModel):
    name: str
    amount_cents: int
    status: str
    prerequisites: list[SponsorTicketPrereqInfo] = []
    bid_id: int | None = None
    payment_id: int | None = None
    payment_receipt_number: str | None = None
    payment_status: str | None = None
    payment_created_at: str | None = None


class SponsorTicketResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    event_id: int
    sponsor_user_id: int
    receipt_number: str
    encrypted_qr_payload: str | None = None
    scanned_at: str | None = None
    created_at: str | None = None
    categories: list[SponsorTicketCategoryInfo] = []
    category_names: list[str] = []
    category_count: int = 0
    event_title: str | None = None
    event_status: str | None = None
    event_start_time: str | None = None
    venue_name: str | None = None
    venue_address: str | None = None
    venue_city: str | None = None
    scan_count: int = 0
