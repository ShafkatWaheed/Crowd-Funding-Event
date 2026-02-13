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


class PlatformSettingItem(BaseModel):
    key: str
    value: str
    description: str | None = None


class PlatformSettingUpdate(BaseModel):
    value: str
