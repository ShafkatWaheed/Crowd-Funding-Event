"""Add scan_count column to sponsor_tickets.

Revision ID: jj70j1k2l3m4
Revises: ii60i0j1k2l3
Create Date: 2026-02-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "jj70j1k2l3m4"
down_revision: Union[str, None] = "ii60i0j1k2l3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "sponsor_tickets",
        sa.Column("scan_count", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("sponsor_tickets", "scan_count")
