"""Add purchase_group_id to ticket_sales for multi-ticket purchases.

Revision ID: cc3d4e5f6a7b
Revises: bb2c3d4e5f6a
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "cc3d4e5f6a7b"
down_revision = "bb2c3d4e5f6a"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "ticket_sales",
        sa.Column("purchase_group_id", sa.String(32), nullable=True, index=True),
    )


def downgrade() -> None:
    op.drop_column("ticket_sales", "purchase_group_id")
