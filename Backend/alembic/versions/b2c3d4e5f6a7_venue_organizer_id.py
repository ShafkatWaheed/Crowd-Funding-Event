"""Add organizer_id to venues (each venue owned by one organizer).

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2025-02-07

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("venues", sa.Column("organizer_id", sa.Integer(), nullable=True))
    # Backfill: set to first organizer/admin, else first user
    op.execute("""
        UPDATE venues v
        SET organizer_id = COALESCE(
            (SELECT id FROM users WHERE role IN ('organizer', 'admin') ORDER BY id LIMIT 1),
            (SELECT id FROM users ORDER BY id LIMIT 1)
        )
    """)
    op.alter_column("venues", "organizer_id", nullable=False)
    op.create_foreign_key("venues_organizer_id_fkey", "venues", "users", ["organizer_id"], ["id"])
    op.create_index(op.f("ix_venues_organizer_id"), "venues", ["organizer_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_venues_organizer_id"), table_name="venues")
    op.drop_constraint("venues_organizer_id_fkey", "venues", type_="foreignkey")
    op.drop_column("venues", "organizer_id")
