"""Add phone column to users table.

Revision ID: g8h9i0j1k2l3
Revises: a8b9c0d1e2f3
Create Date: 2026-02-12
"""
from alembic import op
import sqlalchemy as sa

revision = "g8h9i0j1k2l3"
down_revision = "a8b9c0d1e2f3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("phone", sa.String(30), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "phone")
