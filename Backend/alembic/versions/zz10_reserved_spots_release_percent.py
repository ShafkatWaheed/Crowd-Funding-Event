"""Add reserved_spots_release_percent and release_tier_spot_limits to events

Revision ID: zz10_reserved_spots_release_percent
Revises: zz09_add_is_featured_ticket_tier
Create Date: 2026-03-10
"""
import sqlalchemy as sa
from alembic import op

revision = "zz10_spots_release_pct"
down_revision = "zz09_add_is_featured_ticket_tier"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("reserved_spots_release_percent", sa.Integer(), nullable=True))
    op.add_column("events", sa.Column("release_tier_spot_limits", sa.Boolean(), nullable=False, server_default="false"))


def downgrade() -> None:
    op.drop_column("events", "release_tier_spot_limits")
    op.drop_column("events", "reserved_spots_release_percent")
