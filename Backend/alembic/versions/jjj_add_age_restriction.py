"""add age_restricted and min_age columns to events

Revision ID: jjj_add_age_restriction
Revises: iii_bid_chat_metadata
Create Date: 2026-02-27
"""
from alembic import op
import sqlalchemy as sa

revision = "jjj_add_age_restriction"
down_revision = "iii_bid_chat_metadata"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column("age_restricted", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column(
        "events",
        sa.Column("min_age", sa.Integer(), nullable=False, server_default=sa.text("18")),
    )


def downgrade() -> None:
    op.drop_column("events", "min_age")
    op.drop_column("events", "age_restricted")
