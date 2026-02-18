"""Phase 20C: Sponsor bids.

Revision ID: cc20c3d4e5f6
Revises: bb20b2c3d4e5
Create Date: 2026-02-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "cc20c3d4e5f6"
down_revision: Union[str, None] = "bb20b2c3d4e5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("DO $$ BEGIN CREATE TYPE bidstatus AS ENUM ('pending', 'accepted', 'rejected', 'withdrawn', 'paid'); EXCEPTION WHEN duplicate_object THEN NULL; END $$")

    op.create_table(
        "sponsor_bids",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("category_id", sa.Integer, sa.ForeignKey("sponsorship_categories.id"), nullable=False),
        sa.Column("sponsor_user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("amount_cents", sa.Integer, nullable=False),
        sa.Column("proposal_text", sa.Text, nullable=True),
        sa.Column("status", sa.VARCHAR(20), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("category_id", "sponsor_user_id", name="uq_sponsor_bids_category_user"),
    )
    op.execute("ALTER TABLE sponsor_bids ALTER COLUMN status DROP DEFAULT")
    op.execute("ALTER TABLE sponsor_bids ALTER COLUMN status TYPE bidstatus USING status::bidstatus")
    op.execute("ALTER TABLE sponsor_bids ALTER COLUMN status SET DEFAULT 'pending'::bidstatus")


def downgrade() -> None:
    op.drop_table("sponsor_bids")
    sa.Enum(name="bidstatus").drop(op.get_bind(), checkfirst=True)
