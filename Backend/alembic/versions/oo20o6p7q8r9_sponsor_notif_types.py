"""Add sponsor_payment_received and sponsor_refunded notification types.

Revision ID: oo20o6p7q8r9
Revises: nn10n5o6p7q8
Create Date: 2026-02-21
"""
from alembic import op

revision = "oo20o6p7q8r9"
down_revision = "nn10n5o6p7q8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'sponsor_payment_received'")
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'sponsor_refunded'")


def downgrade() -> None:
    pass
