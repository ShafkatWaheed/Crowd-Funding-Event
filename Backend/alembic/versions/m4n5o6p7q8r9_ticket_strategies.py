"""Ticket strategies: reusable ticketing templates.

Revision ID: m4n5o6p7q8r9
Revises: l3m4n5o6p7q8
Create Date: 2026-02-12
"""
from alembic import op
import sqlalchemy as sa

revision = "m4n5o6p7q8r9"
down_revision = "l3m4n5o6p7q8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create ticket_strategies table
    op.create_table(
        "ticket_strategies",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("organizer_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # Create ticket_strategy_tiers table
    op.create_table(
        "ticket_strategy_tiers",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("strategy_id", sa.Integer, sa.ForeignKey("ticket_strategies.id"), nullable=False, index=True),
        sa.Column("name", sa.String(64), nullable=False),
        sa.Column("price_cents", sa.Integer, nullable=False),
        sa.Column("quantity", sa.Integer, nullable=False, server_default="0"),
        sa.Column("display_order", sa.Integer, nullable=False, server_default="0"),
    )

    # Add ticket_strategy_id FK to events table
    op.add_column("events", sa.Column("ticket_strategy_id", sa.Integer, sa.ForeignKey("ticket_strategies.id"), nullable=True))
    op.create_index("ix_events_ticket_strategy_id", "events", ["ticket_strategy_id"])


def downgrade() -> None:
    op.drop_index("ix_events_ticket_strategy_id", table_name="events")
    op.drop_column("events", "ticket_strategy_id")
    op.drop_table("ticket_strategy_tiers")
    op.drop_table("ticket_strategies")
