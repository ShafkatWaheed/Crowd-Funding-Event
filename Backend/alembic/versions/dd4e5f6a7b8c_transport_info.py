"""Add parking/transport info fields to events.

Revision ID: dd4e5f6a7b8c
Revises: cc3d4e5f6a7b
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "dd4e5f6a7b8c"
down_revision = "cc3d4e5f6a7b"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("parking_info", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("transit_info", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("rideshare_info", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("accessibility_info", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("events", "accessibility_info")
    op.drop_column("events", "rideshare_info")
    op.drop_column("events", "transit_info")
    op.drop_column("events", "parking_info")
