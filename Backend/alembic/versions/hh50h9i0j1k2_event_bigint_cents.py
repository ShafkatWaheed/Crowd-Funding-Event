"""Widen events.funding_goal_cents and events.min_pledge_cents from INTEGER to BIGINT.

Revision ID: hh50h9i0j1k2
Revises: gg40g8h9i0j1
Create Date: 2026-02-20
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "hh50h9i0j1k2"
down_revision: Union[str, None] = "gg40g8h9i0j1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COLUMNS = [
    ("events", "funding_goal_cents", True),
    ("events", "min_pledge_cents", False),
]


def upgrade() -> None:
    for table, col, nullable in _COLUMNS:
        op.alter_column(
            table, col,
            type_=sa.BigInteger(),
            existing_type=sa.Integer(),
            existing_nullable=nullable,
        )


def downgrade() -> None:
    for table, col, nullable in _COLUMNS:
        op.alter_column(
            table, col,
            type_=sa.Integer(),
            existing_type=sa.BigInteger(),
            existing_nullable=nullable,
        )
