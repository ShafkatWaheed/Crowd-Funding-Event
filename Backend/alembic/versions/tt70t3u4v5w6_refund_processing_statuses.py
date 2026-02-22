"""Add refund_processing and refund_failed statuses to funding, ticket, and sponsor enums.

Revision ID: tt70t3u4v5w6
Revises: ss60s1t2u3v4
Create Date: 2026-02-22
"""
from alembic import op

revision = "tt70t3u4v5w6"
down_revision = "ss60s1t2u3v4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE fundingstatus ADD VALUE IF NOT EXISTS 'refund_processing'")
    op.execute("ALTER TYPE fundingstatus ADD VALUE IF NOT EXISTS 'refund_failed'")

    op.execute("ALTER TYPE ticketsalestatus ADD VALUE IF NOT EXISTS 'refund_requested'")
    op.execute("ALTER TYPE ticketsalestatus ADD VALUE IF NOT EXISTS 'refund_processing'")
    op.execute("ALTER TYPE ticketsalestatus ADD VALUE IF NOT EXISTS 'refunded'")
    op.execute("ALTER TYPE ticketsalestatus ADD VALUE IF NOT EXISTS 'refund_failed'")

    op.execute("ALTER TYPE paymentstatus ADD VALUE IF NOT EXISTS 'refund_processing'")
    op.execute("ALTER TYPE paymentstatus ADD VALUE IF NOT EXISTS 'refund_failed'")


def downgrade() -> None:
    pass
