"""make dispute user_id nullable

Revision ID: eb820e134c99
Revises: zz04_settings_warning
Create Date: 2026-03-02 04:32:08.705546

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'eb820e134c99'
down_revision: Union[str, None] = 'zz04_settings_warning'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("disputes", "user_id", existing_type=sa.Integer(), nullable=True)


def downgrade() -> None:
    op.alter_column("disputes", "user_id", existing_type=sa.Integer(), nullable=False)
