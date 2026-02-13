"""Add quantity to ticket_tiers, waitlisted status to ticket_sales

Revision ID: x5y6z7a8b9c0
Revises: w4x5y6z7a8b9
Create Date: 2026-02-10
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "x5y6z7a8b9c0"
down_revision: Union[str, None] = "w4x5y6z7a8b9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add quantity column to ticket_tiers (0 = unlimited)
    op.add_column(
        "ticket_tiers",
        sa.Column("quantity", sa.Integer(), nullable=False, server_default="0"),
    )

    # Add 'waitlisted' to the ticketsalestatus enum
    # For PostgreSQL, we need to alter the enum type
    op.execute("ALTER TYPE ticketsalestatus ADD VALUE IF NOT EXISTS 'waitlisted'")


def downgrade() -> None:
    op.drop_column("ticket_tiers", "quantity")
    # Note: PostgreSQL does not support removing values from enum types easily
