"""Add bookmarks table.

Revision ID: ii60i0j1k2l3
Revises: hh50h9i0j1k2
Create Date: 2026-02-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "ii60i0j1k2l3"
down_revision: Union[str, None] = "hh50h9i0j1k2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "bookmarks",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "event_id", name="uq_bookmarks_user_event"),
    )
    op.create_index("ix_bookmarks_user_id", "bookmarks", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_bookmarks_user_id", table_name="bookmarks")
    op.drop_table("bookmarks")
