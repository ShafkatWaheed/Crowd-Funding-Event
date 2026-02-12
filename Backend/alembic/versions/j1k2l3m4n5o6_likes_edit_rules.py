"""Add like_count, dislike_count to events; event_reactions table.

Revision ID: j1k2l3m4n5o6
Revises: i0j1k2l3m4n5
Create Date: 2026-02-12
"""
from alembic import op
import sqlalchemy as sa

revision = "j1k2l3m4n5o6"
down_revision = "i0j1k2l3m4n5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Like/dislike counts on events
    op.add_column("events", sa.Column("like_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("events", sa.Column("dislike_count", sa.Integer(), nullable=False, server_default="0"))

    # Reactions table
    op.create_table(
        "event_reactions",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("reaction", sa.String(10), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("event_id", "user_id", name="uq_event_reactions_event_user"),
    )


def downgrade() -> None:
    op.drop_table("event_reactions")
    op.drop_column("events", "dislike_count")
    op.drop_column("events", "like_count")
