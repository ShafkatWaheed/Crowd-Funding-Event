"""Add spot reservation fields: reserved_spots + receipt_number on fundings, max_reserved_spots_per_user on events

Revision ID: aa1b2c3d4e5f
Revises: z7a8b9c0d1e2
Create Date: 2026-02-10
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "aa1b2c3d4e5f"
down_revision: Union[str, None] = "z7a8b9c0d1e2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Events: organizer-defined limit on spots per user
    op.add_column("events", sa.Column("max_reserved_spots_per_user", sa.Integer(), nullable=False, server_default="0"))

    # Fundings: reserved spots per pledge + pledge receipt number
    op.add_column("fundings", sa.Column("reserved_spots", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("fundings", sa.Column("receipt_number", sa.String(32), nullable=True))
    op.create_index("ix_fundings_receipt_number", "fundings", ["receipt_number"], unique=True)

    # Back-fill existing pledges with receipt numbers
    conn = op.get_bind()
    rows = conn.execute(sa.text("SELECT id, created_at, event_id FROM fundings ORDER BY id")).fetchall()
    for row in rows:
        ts = row.created_at.strftime("%Y%m%d") if row.created_at else "00000000"
        receipt = f"PLG-{ts}-{row.event_id}-{row.id}"
        conn.execute(
            sa.text("UPDATE fundings SET receipt_number = :rn WHERE id = :id"),
            {"rn": receipt, "id": row.id},
        )


def downgrade() -> None:
    op.drop_index("ix_fundings_receipt_number", table_name="fundings")
    op.drop_column("fundings", "receipt_number")
    op.drop_column("fundings", "reserved_spots")
    op.drop_column("events", "max_reserved_spots_per_user")
