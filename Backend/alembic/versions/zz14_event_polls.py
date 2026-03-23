"""Add event_polls and event_poll_votes tables for live event polling.

Revision ID: zz14_event_polls
Revises: zz13_private_event
Create Date: 2026-03-12
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "zz14_event_polls"
down_revision = "zz13_private_event"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "event_polls",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False),
        sa.Column("organizer_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("question", sa.String(500), nullable=False),
        sa.Column("options", JSONB(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("is_closed", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("show_results_while_open", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_event_polls_event_id", "event_polls", ["event_id"])

    op.create_table(
        "event_poll_votes",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("poll_id", sa.Integer(), sa.ForeignKey("event_polls.id"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("option_index", sa.SmallInteger(), nullable=False),
        sa.Column("voted_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("poll_id", "user_id", name="uq_poll_vote_user"),
    )
    op.create_index("ix_event_poll_votes_poll_id", "event_poll_votes", ["poll_id"])


def downgrade() -> None:
    op.drop_index("ix_event_poll_votes_poll_id", "event_poll_votes")
    op.drop_table("event_poll_votes")
    op.drop_index("ix_event_polls_event_id", "event_polls")
    op.drop_table("event_polls")
