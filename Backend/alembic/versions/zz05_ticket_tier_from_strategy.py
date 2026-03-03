"""Add from_strategy flag to ticket_tiers.

Revision ID: zz05_tier_from_strategy
Revises: eb820e134c99
Create Date: 2026-03-03
"""
from alembic import op
import sqlalchemy as sa

revision = "zz05_tier_from_strategy"
down_revision = "eb820e134c99"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "ticket_tiers",
        sa.Column("from_strategy", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )


def downgrade() -> None:
    op.drop_column("ticket_tiers", "from_strategy")
