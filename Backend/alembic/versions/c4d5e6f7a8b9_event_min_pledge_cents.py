"""Add min_pledge_cents to events (mandatory minimum pledge amount).

Revision ID: c4d5e6f7a8b9
Revises: b2c3d4e5f6a7
Create Date: 2025-02-08

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "c4d5e6f7a8b9"
down_revision: Union[str, None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("events", sa.Column("min_pledge_cents", sa.Integer(), nullable=True))
    op.execute("UPDATE events SET min_pledge_cents = 1 WHERE min_pledge_cents IS NULL")
    op.alter_column(
        "events",
        "min_pledge_cents",
        existing_type=sa.Integer(),
        nullable=False,
    )


def downgrade() -> None:
    op.drop_column("events", "min_pledge_cents")
