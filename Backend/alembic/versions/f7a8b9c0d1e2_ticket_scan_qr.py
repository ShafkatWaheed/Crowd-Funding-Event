"""Add ticket_code, scanned_at, scanned_by_id for QR scan and scan tracking.

Revision ID: f7a8b9c0d1e2
Revises: e6f7a8b9c0d1
Create Date: 2025-02-08

"""
from typing import Sequence, Union
import uuid

from alembic import op
import sqlalchemy as sa

revision: str = "f7a8b9c0d1e2"
down_revision: Union[str, None] = "e6f7a8b9c0d1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("ticket_sales", sa.Column("ticket_code", sa.String(64), nullable=True))
    op.add_column("ticket_sales", sa.Column("scanned_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("ticket_sales", sa.Column("scanned_by_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_ticket_sales_scanned_by_id_users",
        "ticket_sales",
        "users",
        ["scanned_by_id"],
        ["id"],
    )

    # Backfill unique ticket_code for existing rows
    conn = op.get_bind()
    result = conn.execute(sa.text("SELECT id FROM ticket_sales WHERE ticket_code IS NULL"))
    rows = result.fetchall()
    for (row_id,) in rows:
        code = uuid.uuid4().hex[:32]
        conn.execute(sa.text("UPDATE ticket_sales SET ticket_code = :code WHERE id = :id"), {"code": code, "id": row_id})

    op.alter_column("ticket_sales", "ticket_code", nullable=False)
    op.create_index("ix_ticket_sales_ticket_code", "ticket_sales", ["ticket_code"], unique=True)
    op.create_index("ix_ticket_sales_scanned_by_id", "ticket_sales", ["scanned_by_id"])


def downgrade() -> None:
    op.drop_index("ix_ticket_sales_scanned_by_id", "ticket_sales")
    op.drop_index("ix_ticket_sales_ticket_code", "ticket_sales")
    op.drop_constraint("fk_ticket_sales_scanned_by_id_users", "ticket_sales", type_="foreignkey")
    op.drop_column("ticket_sales", "scanned_by_id")
    op.drop_column("ticket_sales", "scanned_at")
    op.drop_column("ticket_sales", "ticket_code")
