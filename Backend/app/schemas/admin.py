# Admin request/response schemas.
from datetime import datetime

from pydantic import BaseModel


class AdminUserItem(BaseModel):
    id: int
    email: str
    display_name: str | None
    role: str
    created_at: datetime


class ApproveBody(BaseModel):
    approved: bool  # True = approve, False = reject


class AdminEventItem(BaseModel):
    id: int
    title: str
    status: str
    organizer_id: int


class AdminStats(BaseModel):
    events_total: int
    events_pending: int
    events_live: int
    users_total: int
    total_ticket_commission_cents: int = 0
    total_funding_commission_cents: int = 0
    total_escrow_held_cents: int = 0


class PlatformSettingItem(BaseModel):
    key: str
    value: str
    description: str | None = None


class PlatformSettingUpdate(BaseModel):
    value: str


class AdminTicketItem(BaseModel):
    """One ticket sale for admin list (all events)."""
    id: int
    event_id: int
    event_title: str | None
    user_id: int
    attendee_display_name: str | None
    tier_name: str | None
    amount_paid_cents: int
    status: str
    created_at: datetime


class AdminPledgeItem(BaseModel):
    """One pledge for admin list (all events)."""
    id: int
    event_id: int
    event_title: str | None
    user_id: int | None
    user_display_name: str | None
    amount_cents: int
    status: str
    is_guest: bool = False
    created_at: datetime


# ----- Admin User Detail (role-based) -----

class AdminUserDetailTicketItem(BaseModel):
    """Ticket item for admin user detail (customer tickets or organizer ticket_sales)."""
    id: int
    event_id: int
    event_title: str | None
    tier_name: str | None
    amount_paid_cents: int
    status: str
    created_at: datetime
    attendee_display_name: str | None = None  # for organizer ticket_sales (buyer)


class AdminUserDetailPledgeItem(BaseModel):
    """Pledge item for admin user detail."""
    id: int
    event_id: int
    event_title: str | None
    user_display_name: str | None
    amount_cents: int
    status: str
    is_guest: bool = False
    reserved_spots: int = 0
    created_at: datetime


class AdminUserDetailEventItem(BaseModel):
    """Event item for admin user detail (enriched for organizer view)."""
    id: int
    title: str
    status: str
    organizer_id: int | None = None
    description: str | None = None
    genre: str | None = None
    max_capacity: int | None = None
    registration_type: str | None = None
    registration_count: int = 0
    funding_goal_cents: int | None = None
    min_pledge_cents: int = 0
    ticket_strategy_name: str | None = None
    venue_name: str | None = None
    venue_address: str | None = None
    review_notes: str | None = None
    review_log: list[dict] = []
    validation_warnings: list[str] = []
    cancellation_reason: str | None = None
    pending_extension: dict | None = None
    pending_cancellation: dict | None = None
    created_at: datetime | None = None
    start_time: datetime | None = None
    end_time: datetime | None = None
    funding_end_at: datetime | None = None
    has_schedule: bool = False
    community_rules: bool = False
    ticket_tiers_count: int = 0
    sponsorship_categories_count: int = 0
    milestones_count: int = 0
    user_ticket_count: int | None = None
    user_pledge_count: int | None = None
    user_pledge_total_cents: int | None = None
    user_reserved_spots: int | None = None
    user_donation_count: int | None = None
    user_donation_total_cents: int | None = None


class AdminUserDetailSponsorItem(BaseModel):
    """Sponsor summary for organizer's events."""
    sponsor_user_id: int
    company_name: str | None
    contact_name: str | None
    total_bids: int
    total_amount_cents: int


class AdminUserDetailDiscountItem(BaseModel):
    """UserEventDiscount for organizer's events."""
    event_id: int
    event_title: str | None
    user_id: int
    user_display_name: str | None
    discount_type: str
    value: int


class AdminSponsorshipBidItem(BaseModel):
    """Single bid in sponsor's sponsorships."""
    bid_id: int
    category_id: int
    category_name: str | None
    amount_cents: int
    status: str
    can_refund: bool = False


class AdminSponsorshipEventItem(BaseModel):
    """Event with bids for sponsor admin detail."""
    event_id: int
    event_title: str | None
    bids: list[AdminSponsorshipBidItem]


class AdminUserDetailResponse(BaseModel):
    """Role-based admin user detail."""
    id: int
    email: str
    display_name: str | None
    role: str
    created_at: datetime
    tickets: list[AdminUserDetailTicketItem] | None = None
    pledges: list[AdminUserDetailPledgeItem] | None = None
    events: list[AdminUserDetailEventItem] | None = None
    ticket_sales: list[AdminUserDetailTicketItem] | None = None
    sponsors: list[AdminUserDetailSponsorItem] | None = None
    discounts: list[AdminUserDetailDiscountItem] | None = None
    sponsorships: list[AdminSponsorshipEventItem] | None = None
    sponsor_bids: list[AdminSponsorshipEventItem] | None = None
    escrows: list[dict] | None = None
