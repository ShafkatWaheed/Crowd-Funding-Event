"""
Pydantic schemas for event polls.
"""
from datetime import datetime
from pydantic import BaseModel, field_validator


class PollCreate(BaseModel):
    question: str
    options: list[str]
    show_results_while_open: bool = True

    @field_validator("question")
    @classmethod
    def question_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Question must not be empty")
        return v.strip()

    @field_validator("options")
    @classmethod
    def validate_options(cls, v: list[str]) -> list[str]:
        cleaned = [o.strip() for o in v if o.strip()]
        if len(cleaned) < 2:
            raise ValueError("At least 2 options are required")
        if len(cleaned) > 6:
            raise ValueError("At most 6 options are allowed")
        return cleaned


class PollVoteRequest(BaseModel):
    option_index: int


class PollOptionResult(BaseModel):
    index: int
    text: str
    vote_count: int
    percentage: float


class PollResponse(BaseModel):
    id: int
    event_id: int
    organizer_id: int
    question: str
    options: list[str]
    is_active: bool
    is_closed: bool
    show_results_while_open: bool
    created_at: datetime
    closed_at: datetime | None = None
    # viewer-specific fields
    viewer_vote_index: int | None = None
    results: list[PollOptionResult] | None = None
    total_votes: int = 0

    model_config = {"from_attributes": True}
