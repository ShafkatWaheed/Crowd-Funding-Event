"""Add community_rules boolean flag to events

Revision ID: w4x5y6z7a8b9
Revises: v3w4x5y6z7a8
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "w4x5y6z7a8b9"
down_revision = "v3w4x5y6z7a8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("community_rules", sa.Boolean, nullable=False, server_default="false"))
    # Backfill: set community_rules=true for existing events with genre='community'
    op.execute("UPDATE events SET community_rules = true WHERE genre = 'community'")


def downgrade() -> None:
    op.drop_column("events", "community_rules")
