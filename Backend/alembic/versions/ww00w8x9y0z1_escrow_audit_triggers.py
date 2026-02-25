"""Add ticket_selling_started_at column, waived escrow status, and new escrow trigger settings.

Revision ID: ww00w8x9y0z1
Revises: vv90v7w8x9y0
Create Date: 2026-02-24
"""
from alembic import op
import sqlalchemy as sa

revision = "ww00w8x9y0z1"
down_revision = "vv90v7w8x9y0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("ticket_selling_started_at", sa.DateTime(timezone=True), nullable=True))

    op.execute("ALTER TYPE escrow_status ADD VALUE IF NOT EXISTS 'waived'")

    op.execute("""
        INSERT INTO platform_settings (key, value) VALUES
            ('escrow_stage1_trigger_mode', 'ticket_percent'),
            ('escrow_stage1_ticket_percent', '50'),
            ('escrow_stage2_trigger_mode', 'days_percent'),
            ('escrow_stage2_ticket_percent', '75'),
            ('escrow_stage2_days_percent', '50'),
            ('escrow_stage3_trigger_enabled', 'true'),
            ('escrow_stage3_trigger_mode', 'days_after'),
            ('escrow_stage3_days_after_event', '7')
        ON CONFLICT (key) DO NOTHING
    """)


def downgrade() -> None:
    op.execute("""
        DELETE FROM platform_settings WHERE key IN (
            'escrow_stage1_trigger_mode', 'escrow_stage1_ticket_percent',
            'escrow_stage2_trigger_mode', 'escrow_stage2_ticket_percent', 'escrow_stage2_days_percent',
            'escrow_stage3_trigger_enabled', 'escrow_stage3_trigger_mode', 'escrow_stage3_days_after_event'
        )
    """)

    op.drop_column("events", "ticket_selling_started_at")
