"""Add address, birthday, years_of_experience to users table.

Revision ID: ff30f6a7b8c9
Revises: ee20e5f6a7b8
Create Date: 2026-02-18
"""
from typing import Union
import sqlalchemy as sa
from alembic import op

revision: str = "ff30f6a7b8c9"
down_revision: Union[str, None] = "ee20e5f6a7b8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("address", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("birthday", sa.Date(), nullable=True))
    op.add_column("users", sa.Column("years_of_experience", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "years_of_experience")
    op.drop_column("users", "birthday")
    op.drop_column("users", "address")
