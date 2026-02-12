"""Event lifecycle: new statuses, nullable dates, event_date_deadline.

Revision ID: l3m4n5o6p7q8
Revises: k2l3m4n5o6p7
Create Date: 2026-02-12
"""
from alembic import op
import sqlalchemy as sa

revision = "l3m4n5o6p7q8"
down_revision = "k2l3m4n5o6p7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Make start_time and end_time nullable
    op.alter_column("events", "start_time", existing_type=sa.DateTime(timezone=True), nullable=True)
    op.alter_column("events", "end_time", existing_type=sa.DateTime(timezone=True), nullable=True)

    # Make refund_deadline_days nullable (only relevant when funding is set)
    op.alter_column("events", "refund_deadline_days", existing_type=sa.Integer(), nullable=True)

    # Add event_date_deadline column
    op.add_column("events", sa.Column("event_date_deadline", sa.DateTime(timezone=True), nullable=True))

    # Update the enum to include new status values
    # For PostgreSQL we need to add new values to the enum type
    # New enum values must be committed before they can be used in DML,
    # so we commit after adding them.
    op.execute("COMMIT")
    op.execute("ALTER TYPE eventstatus ADD VALUE IF NOT EXISTS 'selling_tickets'")
    op.execute("ALTER TYPE eventstatus ADD VALUE IF NOT EXISTS 'waiting_event_date'")
    op.execute("ALTER TYPE eventstatus ADD VALUE IF NOT EXISTS 'completed'")

    # Migrate existing 'ended' events to 'completed'
    op.execute("UPDATE events SET status = 'completed' WHERE status = 'ended'")


def downgrade() -> None:
    # Migrate 'completed' back to 'ended', and new statuses back to 'approved'
    op.execute("UPDATE events SET status = 'ended' WHERE status = 'completed'")
    op.execute("UPDATE events SET status = 'approved' WHERE status = 'selling_tickets'")
    op.execute("UPDATE events SET status = 'approved' WHERE status = 'waiting_event_date'")

    op.drop_column("events", "event_date_deadline")
    op.alter_column("events", "refund_deadline_days", existing_type=sa.Integer(), nullable=False, server_default="7")
    op.alter_column("events", "end_time", existing_type=sa.DateTime(timezone=True), nullable=False)
    op.alter_column("events", "start_time", existing_type=sa.DateTime(timezone=True), nullable=False)
    # Note: Cannot remove enum values in PostgreSQL without recreating the type
