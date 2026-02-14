"""Drop quantity column from ticket_tiers and ticket_strategy_tiers

Revision ID: y6z7a8b9c0d1
Revises: x5y6z7a8b9c0
Create Date: 2026-02-10
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "y6z7a8b9c0d1"
down_revision: Union[str, None] = "x5y6z7a8b9c0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_column("ticket_tiers", "quantity")
    op.drop_column("ticket_strategy_tiers", "quantity")


def downgrade() -> None:
    op.add_column(
        "ticket_tiers",
        sa.Column("quantity", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "ticket_strategy_tiers",
        sa.Column("quantity", sa.Integer(), nullable=False, server_default="0"),
    )
