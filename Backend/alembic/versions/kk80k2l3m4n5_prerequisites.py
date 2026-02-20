"""Add prerequisite tables.

Revision ID: kk80k2l3m4n5
Revises: jj70j1k2l3m4
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "kk80k2l3m4n5"
down_revision: Union[str, None] = "jj70j1k2l3m4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "category_prerequisites",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("category_id", sa.Integer(), sa.ForeignKey("sponsorship_categories.id"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_required", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_category_prerequisites_cat", "category_prerequisites", ["category_id"])

    op.create_table(
        "bid_prerequisite_uploads",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("bid_id", sa.Integer(), sa.ForeignKey("sponsor_bids.id"), nullable=False),
        sa.Column("prerequisite_id", sa.Integer(), sa.ForeignKey("category_prerequisites.id"), nullable=False),
        sa.Column("file_url", sa.String(500), nullable=False),
        sa.Column("status", sa.Enum("pending", "approved", "rejected", name="uploadstatus"), nullable=False, server_default="pending"),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewer_note", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_bid_prerequisite_uploads_bid", "bid_prerequisite_uploads", ["bid_id"])


def downgrade() -> None:
    op.drop_table("bid_prerequisite_uploads")
    op.execute("DROP TYPE IF EXISTS uploadstatus")
    op.drop_table("category_prerequisites")
