"""Add co_organizer notification enum values

Revision ID: zz08_co_organizer_notif
Revises: 99be5a74e4b7
Create Date: 2026-03-08
"""
from alembic import op

revision = "zz08_co_organizer_notif"
down_revision = "99be5a74e4b7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'co_organizer_invited'")
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'co_organizer_accepted'")
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'co_organizer_declined'")
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'co_organizer_removed'")


def downgrade() -> None:
    # PostgreSQL does not support removing enum values; downgrade is a no-op.
    pass
