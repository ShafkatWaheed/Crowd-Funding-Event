"""Add milestone discount snapshots, early bird discounts, is_early_bird on fundings,
max_discount_percent on events, and milestone discount fields on event_discounts.

Revision ID: ss60s1t2u3v4
Revises: rr50r0s1t2u3
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "ss60s1t2u3v4"
down_revision: Union[str, None] = "rr50r0s1t2u3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # -- Events: organizer-controlled discount cap --
    op.add_column(
        "events",
        sa.Column("max_discount_percent", sa.Integer(), nullable=False, server_default="100"),
    )

    # -- Fundings: early bird flag --
    op.add_column(
        "fundings",
        sa.Column("is_early_bird", sa.Boolean(), nullable=False, server_default="false"),
    )

    # -- EventDiscount: milestone discount fields --
    op.add_column(
        "event_discounts",
        sa.Column("milestone_percent", sa.Integer(), nullable=True),
    )
    op.add_column(
        "event_discounts",
        sa.Column("milestone_discount_value", sa.Integer(), nullable=True),
    )

    # -- Funding milestone snapshots --
    op.create_table(
        "funding_milestone_snapshots",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False, index=True),
        sa.Column("milestone_percent", sa.Integer(), nullable=False),
        sa.Column("reached_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "funding_milestone_users",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "snapshot_id",
            sa.Integer(),
            sa.ForeignKey("funding_milestone_snapshots.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
    )

    # -- Early bird discounts --
    op.create_table(
        "early_bird_discounts",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False, index=True),
        sa.Column("applies_to", sa.String(20), nullable=False),  # 'funding' | 'tickets'
        sa.Column("window_start", sa.DateTime(timezone=True), nullable=True),
        sa.Column("window_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("discount_type", sa.String(20), nullable=False),  # 'percent' | 'fixed_cents'
        sa.Column("value", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("early_bird_discounts")
    op.drop_table("funding_milestone_users")
    op.drop_table("funding_milestone_snapshots")
    op.drop_column("event_discounts", "milestone_discount_value")
    op.drop_column("event_discounts", "milestone_percent")
    op.drop_column("fundings", "is_early_bird")
    op.drop_column("events", "max_discount_percent")
