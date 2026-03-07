"""Add ticket_sold notification type.

Revision ID: zz07_ticket_sold_notif
Revises: zz06_venue_snapshot
Create Date: 2026-03-07
"""
from alembic import op

revision = "zz07_ticket_sold_notif"
down_revision = "zz06_venue_snapshot"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'ticket_sold'")


def downgrade() -> None:
    pass
