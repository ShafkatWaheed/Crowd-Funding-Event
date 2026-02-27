"""add sponsor_delegates table

Revision ID: fff_sponsor_delegates
Revises: eee_event_policy_columns
Create Date: 2026-02-26
"""
from alembic import op
import sqlalchemy as sa

revision = "fff_sponsor_delegates"
down_revision = "eee_event_policy_columns"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sponsor_delegates",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("sponsor_ticket_id", sa.Integer, sa.ForeignKey("sponsor_tickets.id"), nullable=False, index=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("phone", sa.String(50), nullable=True),
        sa.Column("checked_in", sa.Boolean, nullable=False, server_default=sa.text("false")),
        sa.Column("checked_in_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("sponsor_ticket_id", "email", name="uq_sponsor_delegate_ticket_email"),
    )


def downgrade() -> None:
    op.drop_table("sponsor_delegates")
