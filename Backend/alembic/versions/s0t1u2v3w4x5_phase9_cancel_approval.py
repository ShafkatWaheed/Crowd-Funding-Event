"""Phase 9.2: pending_cancellation JSON column on events.

Revision ID: s0t1u2v3w4x5
Revises: r9s0t1u2v3w4
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "s0t1u2v3w4x5"
down_revision = "r9s0t1u2v3w4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column("pending_cancellation", sa.JSON, nullable=True),
    )


def downgrade() -> None:
    op.drop_column("events", "pending_cancellation")
