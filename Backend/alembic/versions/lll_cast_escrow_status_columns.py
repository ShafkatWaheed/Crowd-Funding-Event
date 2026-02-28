"""Cast ticket_escrows and sponsor_escrows status columns from varchar to escrow_status enum.

ticket_escrows and sponsor_escrows were created with sa.String(32) for their status
column instead of the escrow_status enum type. This causes a ProgrammingError when
SQLAlchemy generates queries with .in_([EscrowStatus.holding, ...]) because PostgreSQL
cannot compare character varying with escrow_status without an explicit cast.

Revision ID: lll_cast_escrow_status_columns
Revises: kkk_add_tax_columns
Create Date: 2026-02-27
"""
from alembic import op

revision = "lll_cast_escrow_status_columns"
down_revision = "kkk_add_tax_columns"
branch_labels = None
depends_on = None


def upgrade() -> None:
    for table in ("ticket_escrows", "sponsor_escrows"):
        op.execute(f"ALTER TABLE {table} ALTER COLUMN status DROP DEFAULT")
        op.execute(
            f"ALTER TABLE {table} ALTER COLUMN status TYPE escrow_status "
            f"USING status::escrow_status"
        )
        op.execute(
            f"ALTER TABLE {table} ALTER COLUMN status SET DEFAULT 'holding'::escrow_status"
        )


def downgrade() -> None:
    for table in ("ticket_escrows", "sponsor_escrows"):
        op.execute(f"ALTER TABLE {table} ALTER COLUMN status DROP DEFAULT")
        op.execute(
            f"ALTER TABLE {table} ALTER COLUMN status TYPE VARCHAR(32) USING status::VARCHAR"
        )
        op.execute(f"ALTER TABLE {table} ALTER COLUMN status SET DEFAULT 'holding'")
