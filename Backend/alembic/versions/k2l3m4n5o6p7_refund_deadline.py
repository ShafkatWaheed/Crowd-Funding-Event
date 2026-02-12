"""Add refund_deadline_days to events.

Revision ID: k2l3m4n5o6p7
Revises: j1k2l3m4n5o6
Create Date: 2026-02-12
"""
from alembic import op
import sqlalchemy as sa

revision = "k2l3m4n5o6p7"
down_revision = "j1k2l3m4n5o6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("refund_deadline_days", sa.Integer(), nullable=False, server_default="7"))


def downgrade() -> None:
    op.drop_column("events", "refund_deadline_days")
