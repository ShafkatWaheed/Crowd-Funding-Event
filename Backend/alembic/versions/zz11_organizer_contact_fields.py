"""Add contact/social fields to users table

Revision ID: zz11_organizer_contact_fields
Revises: zz10_spots_release_pct
Create Date: 2026-03-12
"""
import sqlalchemy as sa
from alembic import op

revision = "zz11_organizer_contact_fields"
down_revision = "zz10_spots_release_pct"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("bio", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("website_url", sa.String(500), nullable=True))
    op.add_column("users", sa.Column("contact_email", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("instagram", sa.String(100), nullable=True))
    op.add_column("users", sa.Column("twitter", sa.String(100), nullable=True))
    op.add_column("users", sa.Column("facebook", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("linkedin", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("youtube", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("tiktok", sa.String(100), nullable=True))


def downgrade() -> None:
    for col in ["tiktok", "youtube", "linkedin", "facebook", "twitter",
                "instagram", "contact_email", "website_url", "bio"]:
        op.drop_column("users", col)
