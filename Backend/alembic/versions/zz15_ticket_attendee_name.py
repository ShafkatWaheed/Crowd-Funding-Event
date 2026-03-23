"""Add attendee_name to ticket_sales.

Revision ID: zz15_ticket_attendee_name
Revises: zz14_event_polls
Create Date: 2026-03-14
"""
import sqlalchemy as sa
from alembic import op

revision = "zz15_ticket_attendee_name"
down_revision = "zz14_event_polls"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "ticket_sales",
        sa.Column("attendee_name", sa.String(150), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("ticket_sales", "attendee_name")
