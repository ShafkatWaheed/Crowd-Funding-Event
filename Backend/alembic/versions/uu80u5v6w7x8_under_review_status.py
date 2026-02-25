"""Add under_review status and review_notes column to events.

Revision ID: uu80u5v6w7x8
Revises: tt70t3u4v5w6
Create Date: 2026-02-24
"""
from alembic import op
import sqlalchemy as sa

revision = "uu80u5v6w7x8"
down_revision = "tt70t3u4v5w6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE eventstatus ADD VALUE IF NOT EXISTS 'under_review'")
    op.add_column("events", sa.Column("review_notes", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("events", "review_notes")
