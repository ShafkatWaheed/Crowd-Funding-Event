"""Widen all money/cents columns from INTEGER to BIGINT.

Covers: fundings, fund_escrows, escrow_releases.

Revision ID: ee20e5f6a7b8
Revises: dd20d4e5f6a7
Create Date: 2026-02-19
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "ee20e5f6a7b8"
down_revision: Union[str, None] = "dd20d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_UPGRADES = [
    ("fundings", "amount_cents"),
    ("fundings", "platform_cut_cents"),
    ("fundings", "net_to_organizer_cents"),
    ("fund_escrows", "total_held_cents"),
    ("fund_escrows", "stage1_released_cents"),
    ("fund_escrows", "stage2_released_cents"),
    ("fund_escrows", "stage3_released_cents"),
    ("escrow_releases", "amount_cents"),
]


def upgrade() -> None:
    for table, col in _UPGRADES:
        op.alter_column(table, col,
                         type_=sa.BigInteger(), existing_type=sa.Integer(), existing_nullable=False)


def downgrade() -> None:
    for table, col in _UPGRADES:
        op.alter_column(table, col,
                         type_=sa.Integer(), existing_type=sa.BigInteger(), existing_nullable=False)
