"""add per-event policy and admin override columns to events

Revision ID: eee_event_policy_columns
Revises: ddd_add_escrow_auto_release
Create Date: 2026-02-26
"""
from alembic import op
import sqlalchemy as sa

revision = "eee_event_policy_columns"
down_revision = "ddd_add_escrow_auto_release"
branch_labels = None
depends_on = None

_ORGANIZER_COLS = [
    ("waitlist_max_size", sa.Integer()),
    ("event_max_images", sa.Integer()),
    ("max_posts_per_day", sa.Integer()),
    ("max_co_organizers", sa.Integer()),
    ("refund_deadline_percent", sa.Integer()),
]

_ADMIN_OVERRIDE_COLS = [
    ("admin_override_waitlist_max_size", sa.Integer()),
    ("admin_override_event_max_images", sa.Integer()),
    ("admin_override_max_posts_per_day", sa.Integer()),
    ("admin_override_max_co_organizers", sa.Integer()),
    ("admin_override_refund_deadline_percent", sa.Integer()),
]


def upgrade() -> None:
    for col_name, col_type in _ORGANIZER_COLS:
        op.add_column("events", sa.Column(col_name, col_type, nullable=True))

    op.add_column(
        "events",
        sa.Column("waitlist_auto_approve", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )

    for col_name, col_type in _ADMIN_OVERRIDE_COLS:
        op.add_column("events", sa.Column(col_name, col_type, nullable=True))


def downgrade() -> None:
    for col_name, _ in reversed(_ADMIN_OVERRIDE_COLS):
        op.drop_column("events", col_name)
    op.drop_column("events", "waitlist_auto_approve")
    for col_name, _ in reversed(_ORGANIZER_COLS):
        op.drop_column("events", col_name)
