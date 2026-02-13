"""Discount strategies: reusable discount templates linked to events.

Revision ID: p7q8r9s0t1u2
Revises: o6p7q8r9s0t1
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "p7q8r9s0t1u2"
down_revision = "o6p7q8r9s0t1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Reusable discount template owned by organizer
    op.create_table(
        "discount_strategies",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("organizer_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("discount_type", sa.String(20), nullable=False),
        sa.Column("value", sa.Integer, nullable=False),
        sa.Column("target", sa.String(16), nullable=False, server_default="all"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # Link table: attach strategies to events (many-to-many)
    op.create_table(
        "event_discount_strategy_links",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False, index=True),
        sa.Column("discount_strategy_id", sa.Integer, sa.ForeignKey("discount_strategies.id"), nullable=False, index=True),
        sa.UniqueConstraint("event_id", "discount_strategy_id", name="uq_event_discount_strategy"),
    )


def downgrade() -> None:
    op.drop_table("event_discount_strategy_links")
    op.drop_table("discount_strategies")
