"""Add organizer_id and is_template to sponsorship_categories for global templates.

Revision ID: nn10n5o6p7q8
Revises: mm00m4n5o6p7
Create Date: 2026-02-20
"""
from alembic import op
import sqlalchemy as sa

revision = "nn10n5o6p7q8"
down_revision = "mm00m4n5o6p7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "sponsorship_categories",
        sa.Column("organizer_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
    )
    op.add_column(
        "sponsorship_categories",
        sa.Column("is_template", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )

    op.execute("""
        UPDATE sponsorship_categories sc
        SET organizer_id = e.organizer_id
        FROM events e
        WHERE sc.event_id = e.id AND sc.organizer_id IS NULL
    """)

    op.alter_column("sponsorship_categories", "event_id", nullable=True)

    op.create_index("ix_sponsorship_categories_organizer", "sponsorship_categories", ["organizer_id"])
    op.create_index("ix_sponsorship_categories_template", "sponsorship_categories", ["is_template"])


def downgrade() -> None:
    op.drop_index("ix_sponsorship_categories_template")
    op.drop_index("ix_sponsorship_categories_organizer")
    op.alter_column("sponsorship_categories", "event_id", nullable=False)
    op.drop_column("sponsorship_categories", "is_template")
    op.drop_column("sponsorship_categories", "organizer_id")
