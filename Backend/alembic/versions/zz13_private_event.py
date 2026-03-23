"""Add is_private and share_token to events.

Revision ID: zz13_private_event
Revises: zz12_organizer_faq
Create Date: 2026-03-12
"""
import sqlalchemy as sa
from alembic import op

revision = "zz13_private_event"
down_revision = "zz12_organizer_faq"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column(
            "is_private",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )
    op.add_column(
        "events",
        sa.Column(
            "share_token",
            sa.String(length=64),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_events_share_token",
        "events",
        ["share_token"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_events_share_token", table_name="events")
    op.drop_column("events", "share_token")
    op.drop_column("events", "is_private")
