from datetime import datetime

from pydantic import BaseModel, field_validator


class OrganizerFaqCreate(BaseModel):
    question: str
    answer: str
    display_order: int = 0

    @field_validator("question", "answer")
    @classmethod
    def not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("must not be empty")
        return v.strip()


class OrganizerFaqUpdate(BaseModel):
    question: str | None = None
    answer: str | None = None
    display_order: int | None = None
    is_active: bool | None = None

    @field_validator("question", "answer", mode="before")
    @classmethod
    def not_empty_if_set(cls, v: str | None) -> str | None:
        if v is not None and not v.strip():
            raise ValueError("must not be empty")
        return v.strip() if v is not None else v


class OrganizerFaqResponse(BaseModel):
    id: int
    organizer_id: int
    question: str
    answer: str
    display_order: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
