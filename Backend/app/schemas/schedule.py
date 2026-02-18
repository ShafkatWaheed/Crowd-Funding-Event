"""Event schedule item request/response schemas."""
from datetime import datetime, date, time

from pydantic import BaseModel, Field, field_validator


class ScheduleItemCreate(BaseModel):
    date: str = Field(..., description="ISO date YYYY-MM-DD")
    start_time: str = Field(..., description="HH:MM (24h)")
    end_time: str = Field(..., description="HH:MM (24h)")
    title: str = Field(..., min_length=1, max_length=200)
    description: str | None = None
    sort_order: int = 0

    @field_validator("date")
    @classmethod
    def validate_date(cls, v: str) -> str:
        date.fromisoformat(v)
        return v

    @field_validator("start_time", "end_time")
    @classmethod
    def validate_time(cls, v: str) -> str:
        parts = v.split(":")
        if len(parts) != 2:
            raise ValueError("Time must be HH:MM")
        time(int(parts[0]), int(parts[1]))
        return v


class ScheduleItemUpdate(BaseModel):
    date: str | None = Field(None, description="ISO date YYYY-MM-DD")
    start_time: str | None = Field(None, description="HH:MM (24h)")
    end_time: str | None = Field(None, description="HH:MM (24h)")
    title: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    sort_order: int | None = None

    @field_validator("date")
    @classmethod
    def validate_date(cls, v: str | None) -> str | None:
        if v is not None:
            date.fromisoformat(v)
        return v

    @field_validator("start_time", "end_time")
    @classmethod
    def validate_time(cls, v: str | None) -> str | None:
        if v is not None:
            parts = v.split(":")
            if len(parts) != 2:
                raise ValueError("Time must be HH:MM")
            time(int(parts[0]), int(parts[1]))
        return v


class ScheduleItemResponse(BaseModel):
    id: int
    event_id: int
    date: str
    start_time: str
    end_time: str
    title: str
    description: str | None = None
    sort_order: int = 0
    overlaps: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class ScheduleDayGroup(BaseModel):
    date: str
    items: list[ScheduleItemResponse]
