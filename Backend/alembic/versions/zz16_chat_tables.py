"""Add chat_channel and chat_conversation tables.

Revision ID: zz16_chat_tables
Revises: zz15_ticket_attendee_name
Create Date: 2026-04-07
"""
import sqlalchemy as sa
from alembic import op

revision = "zz16_chat_tables"
down_revision = "zz15_ticket_attendee_name"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_channels",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("channel_id", sa.String(100), unique=True, nullable=False),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False),
        sa.Column("organizer_user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("event_id", "type", name="uq_chat_channel_event_type"),
    )
    op.create_index("ix_chat_channels_event_id", "chat_channels", ["event_id"])

    op.create_table(
        "chat_conversations",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("conversation_id", sa.String(150), unique=True, nullable=False),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False),
        sa.Column("participant_user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("organizer_user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("event_id", "participant_user_id", name="uq_chat_conv_event_participant"),
    )
    op.create_index("ix_chat_conversations_event_id", "chat_conversations", ["event_id"])
    op.create_index("ix_chat_conversations_participant", "chat_conversations", ["participant_user_id"])


def downgrade() -> None:
    op.drop_table("chat_conversations")
    op.drop_table("chat_channels")
