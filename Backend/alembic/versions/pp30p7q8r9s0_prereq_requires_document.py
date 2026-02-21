"""Add requires_document column to category_prerequisites.

Revision ID: pp30p7q8r9s0
Revises: oo20o6p7q8r9
Create Date: 2026-02-21
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "pp30p7q8r9s0"
down_revision: Union[str, None] = "oo20o6p7q8r9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "category_prerequisites",
        sa.Column("requires_document", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )


def downgrade() -> None:
    op.drop_column("category_prerequisites", "requires_document")
