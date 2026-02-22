"""Add tier-linked funding: link_funding_to_tiers on events,
max_reserved_spots on ticket_tiers, and pledge_spot_reservations table.

Revision ID: rr50r0s1t2u3
Revises: qq40q8r9s0t1
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "rr50r0s1t2u3"
down_revision: Union[str, None] = "qq40q8r9s0t1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("events", sa.Column("link_funding_to_tiers", sa.Boolean(), nullable=False, server_default="false"))
    op.add_column("ticket_tiers", sa.Column("max_reserved_spots", sa.Integer(), nullable=False, server_default="0"))

    op.create_table(
        "pledge_spot_reservations",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("funding_id", sa.Integer(), sa.ForeignKey("fundings.id"), nullable=False, index=True),
        sa.Column("ticket_tier_id", sa.Integer(), sa.ForeignKey("ticket_tiers.id"), nullable=False, index=True),
        sa.Column("spots", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("pledge_spot_reservations")
    op.drop_column("ticket_tiers", "max_reserved_spots")
    op.drop_column("events", "link_funding_to_tiers")
