"""Phase 2: cancellation_reason, registration_count on events; is_guest on fundings.

Revision ID: h9i0j1k2l3m4
Revises: g8h9i0j1k2l3
Create Date: 2026-02-12
"""
from alembic import op
import sqlalchemy as sa

revision = "h9i0j1k2l3m4"
down_revision = "g8h9i0j1k2l3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("cancellation_reason", sa.Text(), nullable=True))
    op.add_column("events", sa.Column("registration_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("fundings", sa.Column("is_guest", sa.Boolean(), nullable=False, server_default="false"))


def downgrade() -> None:
    op.drop_column("fundings", "is_guest")
    op.drop_column("events", "registration_count")
    op.drop_column("events", "cancellation_reason")
