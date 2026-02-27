"""add stage auto_release booleans to all escrow tables

Revision ID: ddd_add_escrow_auto_release
Revises: ccc_add_worker_run_logs
Create Date: 2026-02-26
"""
from alembic import op
import sqlalchemy as sa

revision = "ddd_add_escrow_auto_release"
down_revision = "ccc_worker_run_logs"
branch_labels = None
depends_on = None

_TABLES = ("fund_escrows", "ticket_escrows", "sponsor_escrows")
_COLS = ("stage1_auto_release", "stage2_auto_release", "stage3_auto_release")


def upgrade() -> None:
    for table in _TABLES:
        for col in _COLS:
            op.add_column(table, sa.Column(col, sa.Boolean(), nullable=False, server_default=sa.text("true")))


def downgrade() -> None:
    for table in _TABLES:
        for col in _COLS:
            op.drop_column(table, col)
