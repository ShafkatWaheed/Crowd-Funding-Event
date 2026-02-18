"""Phase 20D: Sponsor payments & tickets.

Revision ID: dd20d4e5f6a7
Revises: cc20c3d4e5f6
Create Date: 2026-02-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "dd20d4e5f6a7"
down_revision: Union[str, None] = "cc20c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("DO $$ BEGIN CREATE TYPE paymentstatus AS ENUM ('pending', 'completed', 'refunded'); EXCEPTION WHEN duplicate_object THEN NULL; END $$")

    op.create_table(
        "sponsor_payments",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("bid_id", sa.Integer, sa.ForeignKey("sponsor_bids.id"), unique=True, nullable=False),
        sa.Column("amount_cents", sa.Integer, nullable=False),
        sa.Column("platform_cut_cents", sa.Integer, nullable=False),
        sa.Column("net_to_organizer_cents", sa.Integer, nullable=False),
        sa.Column("receipt_number", sa.String(100), nullable=False),
        sa.Column("status", sa.VARCHAR(20), nullable=False, server_default="completed"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.execute("ALTER TABLE sponsor_payments ALTER COLUMN status DROP DEFAULT")
    op.execute("ALTER TABLE sponsor_payments ALTER COLUMN status TYPE paymentstatus USING status::paymentstatus")
    op.execute("ALTER TABLE sponsor_payments ALTER COLUMN status SET DEFAULT 'completed'::paymentstatus")

    op.create_table(
        "sponsor_tickets",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False),
        sa.Column("sponsor_user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("qr_data_encrypted", sa.Text, nullable=True),
        sa.Column("receipt_number", sa.String(100), nullable=False),
        sa.Column("scanned_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("event_id", "sponsor_user_id", name="uq_sponsor_tickets_event_user"),
    )


def downgrade() -> None:
    op.drop_table("sponsor_tickets")
    op.drop_table("sponsor_payments")
    sa.Enum(name="paymentstatus").drop(op.get_bind(), checkfirst=True)
