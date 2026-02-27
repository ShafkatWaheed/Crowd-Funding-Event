"""add escrow bank guard: notification types, bank verification columns

Revision ID: ggg_escrow_bank_guard
Revises: fff_sponsor_delegates
Create Date: 2026-02-26
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect as sa_inspect

revision = "ggg_escrow_bank_guard"
down_revision = "fff_sponsor_delegates"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa_inspect(bind)

    # -- Add new NotificationType enum values --
    new_types = [
        "escrow_payout_blocked",
        "escrow_unfreeze_warning",
        "bank_verification_pending",
        "bank_verified",
        "ticket_refund_failed",
        "pledge_refund_failed",
        "sponsor_refund_failed",
        "refund_delayed_organizer",
        "refund_retry_requested",
    ]
    for val in new_types:
        op.execute(f"ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS '{val}'")

    # -- Create BankVerificationStatus enum --
    bankverificationstatus = sa.Enum(
        "pending", "verified", "rejected", name="bankverificationstatus"
    )
    bankverificationstatus.create(bind, checkfirst=True)

    # -- Add verification columns to organizer_bank_accounts --
    cols = {c["name"] for c in insp.get_columns("organizer_bank_accounts")}

    if "verification_status" not in cols:
        op.add_column(
            "organizer_bank_accounts",
            sa.Column(
                "verification_status",
                sa.Enum("pending", "verified", "rejected", name="bankverificationstatus", create_type=False),
                nullable=False,
                server_default="pending",
            ),
        )

    if "rejection_reason" not in cols:
        op.add_column(
            "organizer_bank_accounts",
            sa.Column("rejection_reason", sa.String(500), nullable=True),
        )


def downgrade() -> None:
    op.drop_column("organizer_bank_accounts", "rejection_reason")
    op.drop_column("organizer_bank_accounts", "verification_status")
    sa.Enum(name="bankverificationstatus").drop(op.get_bind(), checkfirst=True)
