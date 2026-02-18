"""Phase 19: Event Schedule / Agenda.

Revision ID: ff6a7b8c9d0e
Revises: ee5f6a7b8c9d
Create Date: 2026-02-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "ff6a7b8c9d0e"
down_revision: Union[str, None] = "ee5f6a7b8c9d"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column("has_schedule", sa.Boolean, nullable=False, server_default="false"),
    )

    op.create_table(
        "event_schedule_items",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False),
        sa.Column("date", sa.Date, nullable=False),
        sa.Column("start_time", sa.Time, nullable=False),
        sa.Column("end_time", sa.Time, nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index(
        "ix_event_schedule_items_event_date_sort",
        "event_schedule_items",
        ["event_id", "date", "sort_order"],
    )


def downgrade() -> None:
    op.drop_index("ix_event_schedule_items_event_date_sort", table_name="event_schedule_items")
    op.drop_table("event_schedule_items")
    op.drop_column("events", "has_schedule")
