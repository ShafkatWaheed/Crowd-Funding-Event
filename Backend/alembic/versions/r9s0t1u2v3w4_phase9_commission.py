"""Phase 9: platform_settings table, commission columns on ticket_sales and fundings.

Revision ID: r9s0t1u2v3w4
Revises: q8r9s0t1u2v3
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "r9s0t1u2v3w4"
down_revision = "q8r9s0t1u2v3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Platform settings table
    op.create_table(
        "platform_settings",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("key", sa.String(64), unique=True, nullable=False, index=True),
        sa.Column("value", sa.Text, nullable=False),
        sa.Column("description", sa.Text, nullable=True),
    )

    # Seed default settings
    op.execute(
        "INSERT INTO platform_settings (key, value, description) VALUES "
        "('ticket_commission_percent', '5', 'Platform commission on ticket sales (percentage)'),"
        "('funding_commission_percent', '3', 'Platform commission on pledges/funding (percentage)'),"
        "('cancel_approval_threshold_percent', '80', 'Pledge % threshold requiring admin approval for cancellation')"
    )

    # 2. Commission columns on ticket_sales
    op.add_column(
        "ticket_sales",
        sa.Column("commission_cents", sa.Integer, nullable=False, server_default="0"),
    )
    op.add_column(
        "ticket_sales",
        sa.Column("net_to_organizer_cents", sa.Integer, nullable=False, server_default="0"),
    )

    # 3. Commission columns on fundings
    op.add_column(
        "fundings",
        sa.Column("platform_cut_cents", sa.Integer, nullable=False, server_default="0"),
    )
    op.add_column(
        "fundings",
        sa.Column("net_to_organizer_cents", sa.Integer, nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("fundings", "net_to_organizer_cents")
    op.drop_column("fundings", "platform_cut_cents")
    op.drop_column("ticket_sales", "net_to_organizer_cents")
    op.drop_column("ticket_sales", "commission_cents")
    op.drop_table("platform_settings")
