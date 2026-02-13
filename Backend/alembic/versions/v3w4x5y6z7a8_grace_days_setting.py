"""Add event_date_grace_days platform setting

Revision ID: v3w4x5y6z7a8
Revises: u2v3w4x5y6z7
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "v3w4x5y6z7a8"
down_revision = "u2v3w4x5y6z7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "INSERT INTO platform_settings (key, value, description) "
        "VALUES ('event_date_grace_days', '7', "
        "'Days organizer has to set event date after funding ends') "
        "ON CONFLICT (key) DO NOTHING"
    )


def downgrade() -> None:
    op.execute("DELETE FROM platform_settings WHERE key = 'event_date_grace_days'")
