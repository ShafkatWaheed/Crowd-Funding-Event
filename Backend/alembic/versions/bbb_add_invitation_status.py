"""Add invitation_status to event_organizers.

Revision ID: bbb_add_invitation_status
Revises: aaa_device_tokens
"""
from alembic import op
import sqlalchemy as sa

revision = "bbb_add_invitation_status"
down_revision = "aaa_device_tokens"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "event_organizers",
        sa.Column("invitation_status", sa.String(10), nullable=False, server_default="accepted"),
    )


def downgrade() -> None:
    op.drop_column("event_organizers", "invitation_status")
