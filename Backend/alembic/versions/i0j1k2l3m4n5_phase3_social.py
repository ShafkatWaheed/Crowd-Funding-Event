"""Phase 3: genre, posts_enabled on events; event_posts table; event_images table.

Revision ID: i0j1k2l3m4n5
Revises: h9i0j1k2l3m4
Create Date: 2026-02-12
"""
from alembic import op
import sqlalchemy as sa

revision = "i0j1k2l3m4n5"
down_revision = "h9i0j1k2l3m4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Event columns
    op.add_column("events", sa.Column("genre", sa.String(50), nullable=True))
    op.add_column("events", sa.Column("posts_enabled", sa.Boolean(), nullable=False, server_default="true"))
    op.create_index("ix_events_genre", "events", ["genre"])

    # Event posts table
    op.create_table(
        "event_posts",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # Event images table
    op.create_table(
        "event_images",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False, index=True),
        sa.Column("image_url", sa.String(500), nullable=False),
        sa.Column("caption", sa.Text(), nullable=True),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("event_images")
    op.drop_table("event_posts")
    op.drop_index("ix_events_genre", "events")
    op.drop_column("events", "posts_enabled")
    op.drop_column("events", "genre")
