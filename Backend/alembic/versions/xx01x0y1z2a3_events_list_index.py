"""Add composite index for event list queries (status, start_time, id).

Revision ID: xx01x0y1z2a3
Revises: ww00w8x9y0z1
Create Date: 2026-02-25

"""
from alembic import op

revision = "xx01x0y1z2a3"
down_revision = "ww00w8x9y0z1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_events_list_status_start_id",
        "events",
        ["status", "start_time", "id"],
    )


def downgrade() -> None:
    op.drop_index("ix_events_list_status_start_id", table_name="events")
