"""Add refund_requested notification type.

Revision ID: zz02_refund_requested
Revises: zz01_ca_bank
Create Date: 2026-02-28
"""
from alembic import op

revision = "zz02_refund_requested"
down_revision = "zz01_ca_bank"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'refund_requested'")


def downgrade() -> None:
    pass
