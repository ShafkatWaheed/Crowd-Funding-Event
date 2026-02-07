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
