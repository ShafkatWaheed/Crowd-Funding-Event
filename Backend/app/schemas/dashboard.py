# Organizer dashboard response schemas.
from datetime import datetime

from pydantic import BaseModel

from app.schemas.event import EventResponse


class KpiItem(BaseModel):
    value: int
    delta_percent: float | None = None


class KpiFloatItem(BaseModel):
    value: float
    delta_percent: float | None = None


class StatusBreakdown(BaseModel):
    status: str
    count: int


class ActivityFeedItem(BaseModel):
    type: str
    event_id: int
    event_title: str
    actor_name: str
    amount_cents: int
    extra: dict | None = None
    created_at: datetime


class OrganizerDashboardResponse(BaseModel):
    total_revenue: KpiItem
    tickets_sold: KpiItem
    total_backers: KpiItem
    total_events: KpiItem
    total_sponsors: KpiItem
    refund_rate: KpiFloatItem
    status_breakdown: list[StatusBreakdown]
    top_events: list[EventResponse]
    trending_events: list[EventResponse]
    popular_events: list[EventResponse]
    recent_activity: list[ActivityFeedItem]


class TimeSeriesPoint(BaseModel):
    date: str
    revenue_cents: int
    tickets_sold: int
    pledges_count: int


class OrganizerTimeSeriesResponse(BaseModel):
    points: list[TimeSeriesPoint]
    granularity: str
