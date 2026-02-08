"""Add ticket tiers, ticket sales, user event discounts, event discount fields.

Revision ID: e6f7a8b9c0d1
Revises: c4d5e6f7a8b9
Create Date: 2025-02-08

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "e6f7a8b9c0d1"
down_revision: Union[str, None] = "c4d5e6f7a8b9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("events", sa.Column("common_discount_percent", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("events", sa.Column("pledge_discount_percent", sa.Integer(), nullable=False, server_default="0"))

    op.create_table(
        "ticket_tiers",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("event_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(64), nullable=False),
        sa.Column("price_cents", sa.Integer(), nullable=False),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_ticket_tiers_event_id", "ticket_tiers", ["event_id"])

    op.create_table(
        "user_event_discounts",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("event_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("discount_type", sa.String(16), nullable=False),
        sa.Column("value", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("event_id", "user_id", name="uq_user_event_discount_event_user"),
    )
    op.create_index("ix_user_event_discounts_event_id", "user_event_discounts", ["event_id"])
    op.create_index("ix_user_event_discounts_user_id", "user_event_discounts", ["user_id"])

    op.create_table(
        "ticket_sales",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("event_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("ticket_tier_id", sa.Integer(), nullable=False),
        sa.Column("amount_paid_cents", sa.Integer(), nullable=False),
        sa.Column("discount_applied_cents", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("extra_perks", sa.Text(), nullable=True),
        sa.Column("status", sa.Enum("purchased", "cancelled", name="ticketsalestatus"), nullable=False, server_default="purchased"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["ticket_tier_id"], ["ticket_tiers.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_ticket_sales_event_id", "ticket_sales", ["event_id"])
    op.create_index("ix_ticket_sales_user_id", "ticket_sales", ["user_id"])
    op.create_index("ix_ticket_sales_ticket_tier_id", "ticket_sales", ["ticket_tier_id"])


def downgrade() -> None:
    op.drop_index("ix_ticket_sales_ticket_tier_id", "ticket_sales")
    op.drop_index("ix_ticket_sales_user_id", "ticket_sales")
    op.drop_index("ix_ticket_sales_event_id", "ticket_sales")
    op.drop_table("ticket_sales")
    op.drop_index("ix_user_event_discounts_user_id", "user_event_discounts")
    op.drop_index("ix_user_event_discounts_event_id", "user_event_discounts")
    op.drop_table("user_event_discounts")
    op.drop_index("ix_ticket_tiers_event_id", "ticket_tiers")
    op.drop_table("ticket_tiers")
    op.drop_column("events", "pledge_discount_percent")
    op.drop_column("events", "common_discount_percent")
    sa.Enum(name="ticketsalestatus").drop(op.get_bind(), checkfirst=True)
