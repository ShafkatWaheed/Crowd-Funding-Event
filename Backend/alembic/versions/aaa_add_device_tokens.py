"""Add device_tokens table for FCM push notifications.

Revision ID: aaa_device_tokens
Revises: zz_fee_cents
Create Date: 2026-02-26
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect as sa_inspect

revision = "aaa_device_tokens"
down_revision = "zz_fee_cents"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa_inspect(bind)
    if "device_tokens" not in inspector.get_table_names():
        op.create_table(
            "device_tokens",
            sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
            sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
            sa.Column("token", sa.String(512), unique=True, nullable=False),
            sa.Column("platform", sa.String(10), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        )


def downgrade() -> None:
    op.drop_table("device_tokens")
