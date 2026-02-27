"""Log of each ARQ cron job execution."""
from datetime import datetime, timezone

from sqlalchemy import DateTime, Integer, String, Text, Float, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class WorkerRunLog(Base):
    __tablename__ = "worker_run_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    task_name: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    duration_ms: Mapped[float | None] = mapped_column(Float, nullable=True)
    items_processed: Mapped[int | None] = mapped_column(Integer, nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True,
    )
    finished_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
