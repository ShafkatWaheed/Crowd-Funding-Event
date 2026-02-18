# Event request/response schemas.
from datetime import datetime
from typing import Literal

from pydantic import BaseModel

# Predefined genres
EVENT_GENRES = [
    "community",
    "music",
    "tech",
    "sports",
    "arts",
    "food",
    "charity",
    "education",
    "business",
    "other",
]


class EventVenueInfo(BaseModel):
    """Venue info included with an event so everyone can see where it is (once venue is used in an event)."""
    id: int
    name: str
    address: str
    city: str
    province: str | None
    lat: float | None
    lng: float | None
    max_capacity: int

    model_config = {"from_attributes": True}


class EventCreate(BaseModel):
    venue_id: int
    title: str
    description: str | None = None
    start_time: str | None = None  # ISO datetime — event date (optional if funding_end_at set)
    end_time: str | None = None
    funding_goal_cents: int | None = None
    funding_end_at: str | None = None  # funding deadline (optional if start_time set)
    min_pledge_cents: int = 500  # required minimum pledge amount in cents
    registration_type: Literal["open", "closed"] = "open"
    max_capacity: int
    max_reserved_spots_per_user: int = 0  # max ticket spots a pledger can reserve (0 = disabled)
    common_discount_percent: int = 0
    pledge_discount_percent: int = 0
    genre: str | None = None
    community_rules: bool = False
    posts_enabled: bool = True
    refund_deadline_days: int | None = None  # auto-calculated as 20% of funding duration; only when funding set
    ticket_strategy_id: int | None = None  # link to a reusable ticket strategy
    # Parking & Transport
    parking_info: str | None = None
    transit_info: str | None = None
    rideshare_info: str | None = None
    accessibility_info: str | None = None
    has_schedule: bool = False
    publish: bool = False  # True = approved immediately, False = draft


class EventUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    venue_id: int | None = None
    funding_goal_cents: int | None = None
    funding_end_at: str | None = None
    min_pledge_cents: int | None = None
    registration_type: Literal["open", "closed"] | None = None
    max_capacity: int | None = None
    max_reserved_spots_per_user: int | None = None
    common_discount_percent: int | None = None
    pledge_discount_percent: int | None = None
    genre: str | None = None
    community_rules: bool | None = None
    posts_enabled: bool | None = None
    refund_deadline_days: int | None = None
    ticket_strategy_id: int | None = None
    # Parking & Transport
    parking_info: str | None = None
    transit_info: str | None = None
    rideshare_info: str | None = None
    accessibility_info: str | None = None
    has_schedule: bool | None = None


class ExtendFundingBody(BaseModel):
    """Extend funding period: new deadline and/or new goal. At least one required. Requires admin approval."""
    funding_end_at: str | None = None  # ISO datetime — new funding deadline
    funding_goal_cents: int | None = None  # new funding goal


class SetEventDateBody(BaseModel):
    """Set or update event date/time. Applies directly (no admin approval)."""
    start_time: str  # ISO datetime — required
    end_time: str  # ISO datetime — required


class UnregisterResponse(BaseModel):
    refunded_cents: int
    pledges_refunded: int
    refund_eligible: bool = True  # False if deadline passed (no refund)


class EventOrganizerItem(BaseModel):
    """One organizer (main or co-) on an event."""
    user_id: int
    display_name: str | None
    email: str
    is_main: bool
    permission: str = "full"  # 'read' or 'full'; main organizer always 'full'


class AddEventOrganizerBody(BaseModel):
    user_id: int
    permission: str = "read"  # 'read' | 'full'


class CancelBody(BaseModel):
    reason: str


class OrganizerTrustInfo(BaseModel):
    """Organizer trust score summary included in event responses."""
    trust_score: float = 0.0
    label: str = "New"            # New / Low / Fair / Good / Excellent
    completed_events: int = 0
    published_events: int = 0


class EventResponse(BaseModel):
    id: int
    organizer_id: int
    venue_id: int
    venue: EventVenueInfo
    title: str
    description: str | None
    start_time: datetime | None
    end_time: datetime | None
    status: str
    registration_type: str
    max_capacity: int
    max_reserved_spots_per_user: int = 0
    funding_goal_cents: int | None
    funding_end_at: datetime | None
    total_pledged_cents: int | None = None  # for cards: "$X of $Y"
    funding_days_left: int | None = None   # days until funding_end_at; <=0 = ended; None = no deadline
    total_reserved_spots: int = 0  # sum of unredeemed reserved spots for the event
    tickets_sold_count: int = 0  # count of purchased tickets (for capacity display)
    min_pledge_cents: int
    common_discount_percent: int
    pledge_discount_percent: int
    cancellation_reason: str | None = None
    registration_count: int = 0
    genre: str | None = None
    community_rules: bool = False
    posts_enabled: bool = True
    refund_deadline_days: int | None = None
    event_date_deadline: datetime | None = None
    ticket_strategy_id: int | None = None
    ticket_strategy_name: str | None = None
    like_count: int = 0
    dislike_count: int = 0  # only populated for admin
    pending_extension: dict | None = None  # pending admin approval extension
    pending_cancellation: dict | None = None  # pending admin approval cancellation
    organizer_trust: OrganizerTrustInfo | None = None  # organizer trust score
    lat: float | None
    lng: float | None
    # Parking & Transport
    parking_info: str | None = None
    transit_info: str | None = None
    rideshare_info: str | None = None
    accessibility_info: str | None = None
    has_schedule: bool = False
    directions_url: str | None = None  # computed from venue address
    created_at: datetime
    updated_at: datetime


class EventPostCreate(BaseModel):
    content: str


class EventPostResponse(BaseModel):
    id: int
    event_id: int
    user_id: int
    author_name: str | None = None
    content: str
    created_at: datetime


class EventImageResponse(BaseModel):
    id: int
    event_id: int
    image_url: str
    caption: str | None
    display_order: int
    created_at: datetime

    model_config = {"from_attributes": True}


class MapEventMarker(BaseModel):
    """Event marker for map view (lat/lng, times, live flag)."""
    id: int
    title: str
    lat: float
    lng: float
    start_time: str | None
    end_time: str | None
    status: str
    is_live: bool
    venue_id: int | None = None
    venue_name: str | None = None


# ─── Event Discounts ───


class EventDiscountCreate(BaseModel):
    name: str
    discount_type: str  # 'pledge_percent' | 'ticket_percent' | 'fixed_cents'
    value: int
    target: str = "all"  # 'all' | 'pledgers' | 'non_pledgers'


class EventDiscountResponse(BaseModel):
    id: int
    event_id: int
    name: str
    discount_type: str
    value: int
    target: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Organizer Customer History ───


class CustomerHistoryItem(BaseModel):
    customer_id: int
    customer_name: str | None
    event_id: int
    event_title: str | None
    scanned_at: datetime
    events_attended: int = 0  # total events attended with this organizer


# ─── Extension Approval ───


class ExtensionApprovalAction(BaseModel):
    action: str  # 'approve' | 'reject'
