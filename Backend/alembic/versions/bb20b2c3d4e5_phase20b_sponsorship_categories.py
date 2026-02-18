"""Phase 20B: Sponsorship categories.

Revision ID: bb20b2c3d4e5
Revises: aa20a1b2c3d4
Create Date: 2026-02-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "bb20b2c3d4e5"
down_revision: Union[str, None] = "aa20a1b2c3d4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "sponsorship_categories",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("image_url", sa.String(500), nullable=True),
        sa.Column("total_spots", sa.Integer, nullable=False),
        sa.Column("filled_spots", sa.Integer, nullable=False, server_default="0"),
        sa.Column("min_bid_cents", sa.Integer, nullable=False),
        sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index(
        "ix_sponsorship_categories_event_sort",
        "sponsorship_categories",
        ["event_id", "sort_order"],
    )


def downgrade() -> None:
    op.drop_index("ix_sponsorship_categories_event_sort", table_name="sponsorship_categories")
    op.drop_table("sponsorship_categories")
