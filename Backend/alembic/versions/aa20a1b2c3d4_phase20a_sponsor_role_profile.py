"""Phase 20A: Sponsor role & profile.

Revision ID: aa20a1b2c3d4
Revises: ff6a7b8c9d0e
Create Date: 2026-02-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "aa20a1b2c3d4"
down_revision: Union[str, None] = "ff6a7b8c9d0e"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'sponsor'")

    op.create_table(
        "sponsor_profiles",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id"), unique=True, nullable=False),
        sa.Column("company_name", sa.String(200), nullable=False),
        sa.Column("contact_name", sa.String(200), nullable=False),
        sa.Column("profession", sa.String(100), nullable=False),
        sa.Column("logo_url", sa.String(500), nullable=True),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("website_url", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.execute(
        "INSERT INTO platform_settings (key, value, description) "
        "VALUES ('sponsor_commission_percent', '5', 'Commission percentage on sponsor payments') "
        "ON CONFLICT (key) DO NOTHING"
    )


def downgrade() -> None:
    op.execute(
        "DELETE FROM platform_settings WHERE key = 'sponsor_commission_percent'"
    )
    op.drop_table("sponsor_profiles")
