"""Add auto_apply to discount links + customer_discount_claims table.

Revision ID: q8r9s0t1u2v3
Revises: p7q8r9s0t1u2
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "q8r9s0t1u2v3"
down_revision = "p7q8r9s0t1u2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add auto_apply flag to the link table
    op.add_column(
        "event_discount_strategy_links",
        sa.Column("auto_apply", sa.Boolean, nullable=False, server_default=sa.text("true")),
    )

    # Customer discount claim table (for non-auto-apply discounts)
    op.create_table(
        "customer_discount_claims",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("link_id", sa.Integer, sa.ForeignKey("event_discount_strategy_links.id"), nullable=False, index=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("claimed_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("link_id", "user_id", name="uq_customer_discount_claim"),
    )


def downgrade() -> None:
    op.drop_table("customer_discount_claims")
    op.drop_column("event_discount_strategy_links", "auto_apply")
