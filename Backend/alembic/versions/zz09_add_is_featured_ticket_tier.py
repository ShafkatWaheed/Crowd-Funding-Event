"""Add is_featured column to ticket_tiers

Revision ID: zz09_add_is_featured_ticket_tier
Revises: zz08_co_organizer_notif
Create Date: 2026-03-10
"""
import sqlalchemy as sa
from alembic import op

revision = "zz09_add_is_featured_ticket_tier"
down_revision = "zz08_co_organizer_notif"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "ticket_tiers",
        sa.Column("is_featured", sa.Boolean(), nullable=False, server_default="false"),
    )


def downgrade() -> None:
    op.drop_column("ticket_tiers", "is_featured")
