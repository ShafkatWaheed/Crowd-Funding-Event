"""add_release_status_to_escrow_releases

Revision ID: 99be5a74e4b7
Revises: zz07_ticket_sold_notif
Create Date: 2026-03-08

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = '99be5a74e4b7'
down_revision: Union[str, None] = 'zz07_ticket_sold_notif'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'escrow_releases',
        sa.Column('release_status', sa.String(length=16), nullable=False, server_default='completed')
    )


def downgrade() -> None:
    op.drop_column('escrow_releases', 'release_status')
