"""Add organizer_faqs table and faq_enabled column on events.

Revision ID: zz12_organizer_faq
Revises: zz11_organizer_contact_fields
Create Date: 2026-03-12
"""
import sqlalchemy as sa
from alembic import op

revision = "zz12_organizer_faq"
down_revision = "zz11_organizer_contact_fields"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "organizer_faqs",
        sa.Column("id", sa.Integer(), nullable=False, autoincrement=True),
        sa.Column("organizer_id", sa.Integer(), nullable=False),
        sa.Column("question", sa.String(length=500), nullable=False),
        sa.Column("answer", sa.Text(), nullable=False),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["organizer_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_organizer_faqs_organizer_id", "organizer_faqs", ["organizer_id"]
    )
    op.add_column(
        "events",
        sa.Column(
            "faq_enabled",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )


def downgrade() -> None:
    op.drop_column("events", "faq_enabled")
    op.drop_index("ix_organizer_faqs_organizer_id", table_name="organizer_faqs")
    op.drop_table("organizer_faqs")
