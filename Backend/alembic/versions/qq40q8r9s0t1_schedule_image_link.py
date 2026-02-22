"""Add image_url, image_caption, link_url to event_schedule_items.

Revision ID: qq40q8r9s0t1
Revises: pp30p7q8r9s0
Create Date: 2026-02-21
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "qq40q8r9s0t1"
down_revision: Union[str, None] = "pp30p7q8r9s0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("event_schedule_items", sa.Column("image_url", sa.String(500), nullable=True))
    op.add_column("event_schedule_items", sa.Column("image_caption", sa.String(200), nullable=True))
    op.add_column("event_schedule_items", sa.Column("link_url", sa.String(500), nullable=True))


def downgrade() -> None:
    op.drop_column("event_schedule_items", "link_url")
    op.drop_column("event_schedule_items", "image_caption")
    op.drop_column("event_schedule_items", "image_url")
