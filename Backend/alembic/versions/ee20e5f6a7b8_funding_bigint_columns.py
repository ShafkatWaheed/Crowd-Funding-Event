"""Funding: widen money columns from INTEGER to BIGINT.

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


def upgrade() -> None:
    op.alter_column("fundings", "amount_cents",
                     type_=sa.BigInteger(), existing_type=sa.Integer(), existing_nullable=False)
    op.alter_column("fundings", "platform_cut_cents",
                     type_=sa.BigInteger(), existing_type=sa.Integer(), existing_nullable=False)
    op.alter_column("fundings", "net_to_organizer_cents",
                     type_=sa.BigInteger(), existing_type=sa.Integer(), existing_nullable=False)


def downgrade() -> None:
    op.alter_column("fundings", "amount_cents",
                     type_=sa.Integer(), existing_type=sa.BigInteger(), existing_nullable=False)
    op.alter_column("fundings", "platform_cut_cents",
                     type_=sa.Integer(), existing_type=sa.BigInteger(), existing_nullable=False)
    op.alter_column("fundings", "net_to_organizer_cents",
                     type_=sa.Integer(), existing_type=sa.BigInteger(), existing_nullable=False)
