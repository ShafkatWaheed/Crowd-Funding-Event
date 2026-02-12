"""Add description to ticket tiers.

Revision ID: n5o6p7q8r9s0
Revises: m4n5o6p7q8r9
Create Date: 2026-02-12
"""
from alembic import op
import sqlalchemy as sa

revision = "n5o6p7q8r9s0"
down_revision = "m4n5o6p7q8r9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("ticket_strategy_tiers", sa.Column("description", sa.Text, nullable=True))
    op.add_column("ticket_tiers", sa.Column("description", sa.Text, nullable=True))


def downgrade() -> None:
    op.drop_column("ticket_tiers", "description")
    op.drop_column("ticket_strategy_tiers", "description")
