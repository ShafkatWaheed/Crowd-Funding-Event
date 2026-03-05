"""Add venue_snapshot JSONB column to events and make venue_id nullable.

Completed/cancelled events snapshot their venue data so edits and
deletions of the venue don't affect historical records.

Revision ID: zz06_venue_snapshot
Revises: zz05_tier_from_strategy
Create Date: 2026-03-05
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "zz06_venue_snapshot"
down_revision = "zz05_tier_from_strategy"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("venue_snapshot", JSONB, nullable=True))
    op.alter_column("events", "venue_id", existing_type=sa.Integer(), nullable=True)

    # Backfill: populate venue_snapshot for existing completed/cancelled events
    op.execute(sa.text("""
        UPDATE events e
        SET venue_snapshot = jsonb_build_object(
            'id', v.id,
            'name', v.name,
            'address', v.address,
            'city', v.city,
            'province', v.province,
            'lat', v.lat,
            'lng', v.lng,
            'max_capacity', v.max_capacity
        )
        FROM venues v
        WHERE e.venue_id = v.id
          AND e.status IN ('completed', 'cancelled')
          AND e.venue_snapshot IS NULL
    """))


def downgrade() -> None:
    op.alter_column("events", "venue_id", existing_type=sa.Integer(), nullable=False)
    op.drop_column("events", "venue_snapshot")
