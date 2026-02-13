"""Phase 9.5: fund_escrows and escrow_releases tables, terms_accepted_at and payout_frozen on events.

Revision ID: t1u2v3w4x5y6
Revises: s0t1u2v3w4x5
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "t1u2v3w4x5y6"
down_revision = "s0t1u2v3w4x5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Fund escrows table
    op.create_table(
        "fund_escrows",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), unique=True, nullable=False, index=True),
        sa.Column("total_held_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("stage1_released_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("stage1_released_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("stage2_released_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("stage2_released_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("stage3_released_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("stage3_released_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.Enum("holding", "partially_released", "fully_released", "refunded", "frozen", name="escrow_status"), nullable=False, server_default="holding"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # 2. Escrow releases audit log
    op.create_table(
        "escrow_releases",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("escrow_id", sa.Integer, sa.ForeignKey("fund_escrows.id"), nullable=False, index=True),
        sa.Column("stage", sa.Integer, nullable=False),
        sa.Column("amount_cents", sa.Integer, nullable=False),
        sa.Column("released_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("released_by", sa.String(32), nullable=False),
        sa.Column("reason", sa.Text, nullable=True),
    )

    # 3. Event columns for terms and payout freeze
    op.add_column("events", sa.Column("terms_accepted_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("events", sa.Column("payout_frozen", sa.Boolean, nullable=False, server_default=sa.text("false")))

    # 4. Seed escrow-related platform settings
    op.execute(
        "INSERT INTO platform_settings (key, value, description) VALUES "
        "('escrow_stage1_percent', '30', 'Percentage of funds released at Stage 1 (planning)'),"
        "('escrow_stage2_percent', '40', 'Percentage of funds released at Stage 2 (48h before event)'),"
        "('escrow_stage3_percent', '30', 'Percentage of funds released at Stage 3 (event completed)'),"
        "('scan_threshold_percent', '25', 'Minimum % of tickets scanned to release Stage 3'),"
        "('new_organizer_deposit_cents', '5000', 'Deposit required from first-time organizers ($50)'),"
        "('stage3_grace_days', '14', 'Days to hold Stage 3 funds for admin review'),"
        "('event_date_deadline_days', '30', 'Days after goal met to set event date before auto-refund')"
    )


def downgrade() -> None:
    op.drop_table("escrow_releases")
    op.drop_table("fund_escrows")
    op.execute("DROP TYPE IF EXISTS escrow_status")
    op.drop_column("events", "payout_frozen")
    op.drop_column("events", "terms_accepted_at")
    op.execute(
        "DELETE FROM platform_settings WHERE key IN "
        "('escrow_stage1_percent','escrow_stage2_percent','escrow_stage3_percent',"
        "'scan_threshold_percent','new_organizer_deposit_cents','stage3_grace_days','event_date_deadline_days')"
    )
