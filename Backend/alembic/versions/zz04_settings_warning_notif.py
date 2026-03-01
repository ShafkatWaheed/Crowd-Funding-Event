"""Add settings_warning notification type.

Revision ID: zz04_settings_warning
Revises: zz03_stripe_fields
Create Date: 2026-03-01
"""
from alembic import op

revision = "zz04_settings_warning"
down_revision = "zz03_stripe_fields"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'settings_warning'")


def downgrade() -> None:
    pass
