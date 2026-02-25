"""Add review_log JSON column to events and event_under_review notification type.

Revision ID: vv90v7w8x9y0
Revises: uu80u5v6w7x8
Create Date: 2026-02-24
"""
from alembic import op
import sqlalchemy as sa

revision = "vv90v7w8x9y0"
down_revision = "uu80u5v6w7x8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("review_log", sa.JSON(), nullable=True))
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'event_under_review'")


def downgrade() -> None:
    op.drop_column("events", "review_log")
