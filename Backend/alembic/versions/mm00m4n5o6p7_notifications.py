"""Add notifications table.

Revision ID: mm00m4n5o6p7
Revises: ll90l3m4n5o6
Create Date: 2026-02-20
"""
from alembic import op
import sqlalchemy as sa

revision = "mm00m4n5o6p7"
down_revision = "ll90l3m4n5o6"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "type",
            sa.Enum(
                "registration_confirmed", "registration_waitlisted",
                "waitlist_approved", "waitlist_rejected",
                "pledge_confirmed", "funding_goal_reached", "milestone_reached",
                "ticket_purchased", "ticket_waitlist_approved", "ticket_waitlist_rejected",
                "refund_issued",
                "event_status_changed", "event_approved", "event_rejected",
                "event_cancelled", "event_updated", "schedule_updated",
                "bid_received", "bid_accepted", "bid_rejected",
                "sponsor_ticket_generated",
                "new_rating_received", "bookmarked_event_update",
                name="notificationtype",
            ),
            nullable=False,
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("data", sa.JSON(), nullable=True),
        sa.Column("is_read", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])
    op.create_index("ix_notifications_user_unread", "notifications", ["user_id", "is_read"])

def downgrade() -> None:
    op.drop_index("ix_notifications_user_unread")
    op.drop_index("ix_notifications_user_id")
    op.drop_table("notifications")
    op.execute("DROP TYPE IF EXISTS notificationtype")
