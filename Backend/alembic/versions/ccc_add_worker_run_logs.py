"""Add worker_run_logs table for ARQ cron job tracking.

Revision ID: ccc_worker_run_logs
Revises: bbb_add_invitation_status
"""
from alembic import op
import sqlalchemy as sa

revision = "ccc_worker_run_logs"
down_revision = "bbb_add_invitation_status"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "worker_run_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("task_name", sa.String(100), nullable=False, index=True),
        sa.Column("status", sa.String(20), nullable=False, index=True),
        sa.Column("duration_ms", sa.Float(), nullable=True),
        sa.Column("items_processed", sa.Integer(), nullable=True),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("worker_run_logs")
