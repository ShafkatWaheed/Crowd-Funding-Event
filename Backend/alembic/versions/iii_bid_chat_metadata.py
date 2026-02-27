"""add chat metadata columns to sponsor_bids + chat_message notification type

Revision ID: iii_bid_chat_metadata
Revises: hhh_kyc_verification
Create Date: 2026-02-27
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect as sa_inspect

revision = "iii_bid_chat_metadata"
down_revision = "hhh_kyc_verification"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa_inspect(conn)
    existing_cols = [c["name"] for c in inspector.get_columns("sponsor_bids")]

    if "last_message_at" not in existing_cols:
        op.add_column(
            "sponsor_bids",
            sa.Column("last_message_at", sa.DateTime(timezone=True), nullable=True),
        )
    if "unread_count_organizer" not in existing_cols:
        op.add_column(
            "sponsor_bids",
            sa.Column("unread_count_organizer", sa.Integer, nullable=False, server_default="0"),
        )
    if "unread_count_sponsor" not in existing_cols:
        op.add_column(
            "sponsor_bids",
            sa.Column("unread_count_sponsor", sa.Integer, nullable=False, server_default="0"),
        )

    if conn.dialect.name == "postgresql":
        op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'chat_message'")


def downgrade() -> None:
    op.drop_column("sponsor_bids", "unread_count_sponsor")
    op.drop_column("sponsor_bids", "unread_count_organizer")
    op.drop_column("sponsor_bids", "last_message_at")
