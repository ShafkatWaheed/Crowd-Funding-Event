"""Add receipt_number column to ticket_sales

Revision ID: z7a8b9c0d1e2
Revises: y6z7a8b9c0d1
Create Date: 2026-02-10
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "z7a8b9c0d1e2"
down_revision: Union[str, None] = "y6z7a8b9c0d1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("ticket_sales", sa.Column("receipt_number", sa.String(32), nullable=True))
    op.create_index("ix_ticket_sales_receipt_number", "ticket_sales", ["receipt_number"], unique=True)

    # Back-fill existing rows with receipt numbers
    conn = op.get_bind()
    rows = conn.execute(sa.text("SELECT id, created_at FROM ticket_sales ORDER BY id")).fetchall()
    for row in rows:
        ts = row.created_at.strftime("%Y%m%d") if row.created_at else "00000000"
        receipt = f"RCP-{ts}-{row.id:06d}"
        conn.execute(
            sa.text("UPDATE ticket_sales SET receipt_number = :rn WHERE id = :id"),
            {"rn": receipt, "id": row.id},
        )


def downgrade() -> None:
    op.drop_index("ix_ticket_sales_receipt_number", table_name="ticket_sales")
    op.drop_column("ticket_sales", "receipt_number")
