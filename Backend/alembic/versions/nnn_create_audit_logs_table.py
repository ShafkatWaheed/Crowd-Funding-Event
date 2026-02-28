"""Create audit_logs table.

The AuditLog model references a table that was never created via migration,
causing 'relation "audit_logs" does not exist' on any admin action that
writes an audit entry (e.g. settings updates).

Revision ID: nnn_create_audit_logs_table
Revises: mmm_create_missing_enum_types
Create Date: 2026-02-27
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "nnn_create_audit_logs_table"
down_revision = "mmm_create_missing_enum_types"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("admin_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("action", sa.String(100), nullable=False, index=True),
        sa.Column("target_type", sa.String(50), nullable=False),
        sa.Column("target_id", sa.String(100), nullable=True),
        sa.Column("details", JSONB, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, index=True),
    )


def downgrade() -> None:
    op.drop_table("audit_logs")
