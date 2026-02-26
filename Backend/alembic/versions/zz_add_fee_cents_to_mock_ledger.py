"""create missing tables and add fee_cents to payment_mock_ledger

Revision ID: zz_fee_cents
Revises: yy02y1z2a3b4
Create Date: 2026-02-25
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect as sa_inspect

revision = "zz_fee_cents"
down_revision = "yy02y1z2a3b4"
branch_labels = None
depends_on = None


def _table_exists(table_name: str) -> bool:
    conn = op.get_bind()
    insp = sa_inspect(conn)
    return table_name in insp.get_table_names()


def _column_exists(table_name: str, column_name: str) -> bool:
    conn = op.get_bind()
    insp = sa_inspect(conn)
    columns = [c["name"] for c in insp.get_columns(table_name)]
    return column_name in columns


def upgrade() -> None:
    if not _table_exists("payment_mock_ledger"):
        op.create_table(
            "payment_mock_ledger",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("transaction_id", sa.String(64), unique=True, nullable=False),
            sa.Column("idempotency_key", sa.String(128), unique=True, nullable=True),
            sa.Column("operation", sa.String(16), nullable=False),
            sa.Column("amount_cents", sa.BigInteger(), nullable=False),
            sa.Column("fee_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("from_account", sa.String(128), nullable=False),
            sa.Column("to_account", sa.String(128), nullable=False),
            sa.Column("description", sa.Text(), nullable=False, server_default=""),
            sa.Column("status", sa.String(32), nullable=False, server_default="pending"),
            sa.Column("authorization_code", sa.String(32), nullable=True),
            sa.Column("receipt_reference", sa.String(64), nullable=True),
            sa.Column("failure_reason", sa.String(64), nullable=True),
            sa.Column("related_type", sa.String(32), nullable=True),
            sa.Column("related_id", sa.Integer(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column("processing_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index("ix_payment_mock_ledger_transaction_id", "payment_mock_ledger", ["transaction_id"])
        op.create_index("ix_payment_mock_ledger_idempotency_key", "payment_mock_ledger", ["idempotency_key"])
    elif not _column_exists("payment_mock_ledger", "fee_cents"):
        op.add_column("payment_mock_ledger", sa.Column("fee_cents", sa.BigInteger(), nullable=False, server_default="0"))

    if not _table_exists("email_mock_log"):
        op.create_table(
            "email_mock_log",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("to_email", sa.String(255), nullable=False, index=True),
            sa.Column("subject", sa.String(500), nullable=False),
            sa.Column("body_html", sa.Text(), nullable=False),
            sa.Column("template_key", sa.String(64), nullable=True),
            sa.Column("status", sa.String(16), nullable=False, server_default="sent"),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )

    if not _table_exists("ledger_entries"):
        op.create_table(
            "ledger_entries",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("transaction_id", sa.String(64), nullable=False, index=True),
            sa.Column("entry_type", sa.String(8), nullable=False),
            sa.Column("account", sa.String(128), nullable=False, index=True),
            sa.Column("amount_cents", sa.BigInteger(), nullable=False),
            sa.Column("description", sa.Text(), nullable=False, server_default=""),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )

    if not _table_exists("disputes"):
        op.create_table(
            "disputes",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("stripe_dispute_id", sa.String(128), unique=True, nullable=True),
            sa.Column("transaction_id", sa.String(64), nullable=False, index=True),
            sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=True, index=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
            sa.Column("amount_cents", sa.Integer(), nullable=False),
            sa.Column("fee_cents", sa.Integer(), nullable=False, server_default="1500"),
            sa.Column("reason", sa.String(64), nullable=False, server_default="product_not_received"),
            sa.Column("status", sa.String(32), nullable=False, server_default="open"),
            sa.Column("evidence_submitted_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("outcome_notes", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )

    if not _table_exists("reconciliation_reports"):
        op.create_table(
            "reconciliation_reports",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("run_date", sa.Date(), unique=True, nullable=False),
            sa.Column("actual_balance_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("expected_balance_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("delta_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("status", sa.String(32), nullable=False, server_default="balanced"),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )

    if not _table_exists("email_templates"):
        op.create_table(
            "email_templates",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("template_key", sa.String(64), unique=True, nullable=False),
            sa.Column("subject", sa.String(500), nullable=False),
            sa.Column("body_html", sa.Text(), nullable=False),
            sa.Column("variables", sa.Text(), nullable=False, server_default="[]"),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )
        op.create_index("ix_email_templates_template_key", "email_templates", ["template_key"])

    if not _table_exists("user_payment_info"):
        op.create_table(
            "user_payment_info",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), unique=True, nullable=False),
            sa.Column("card_holder_name", sa.String(200), nullable=True),
            sa.Column("card_last_four", sa.String(4), nullable=True),
            sa.Column("card_brand", sa.String(32), nullable=True),
            sa.Column("billing_address", sa.String(500), nullable=True),
            sa.Column("payment_method_token", sa.String(256), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )
        op.create_index("ix_user_payment_info_user_id", "user_payment_info", ["user_id"])

    if not _table_exists("organizer_bank_accounts"):
        op.create_table(
            "organizer_bank_accounts",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), unique=True, nullable=False),
            sa.Column("bank_name_encrypted", sa.LargeBinary(), nullable=False),
            sa.Column("account_number_encrypted", sa.LargeBinary(), nullable=False),
            sa.Column("routing_number_encrypted", sa.LargeBinary(), nullable=False),
            sa.Column("account_holder_encrypted", sa.LargeBinary(), nullable=False),
            sa.Column("swift_code_encrypted", sa.LargeBinary(), nullable=True),
            sa.Column("verified", sa.Boolean(), nullable=False, server_default="false"),
            sa.Column("payout_schedule", sa.String(16), nullable=False, server_default="weekly"),
            sa.Column("payout_day", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("min_payout_cents", sa.Integer(), nullable=False, server_default="2500"),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )
        op.create_index("ix_organizer_bank_accounts_user_id", "organizer_bank_accounts", ["user_id"])

    if not _table_exists("ticket_escrows"):
        op.create_table(
            "ticket_escrows",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), unique=True, nullable=False),
            sa.Column("total_held_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("stage1_released_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("stage1_released_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("stage2_released_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("stage2_released_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("stage3_released_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("stage3_released_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("status", sa.String(32), nullable=False, server_default="holding"),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )
        op.create_index("ix_ticket_escrows_event_id", "ticket_escrows", ["event_id"])

    if not _table_exists("sponsor_escrows"):
        op.create_table(
            "sponsor_escrows",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), unique=True, nullable=False),
            sa.Column("total_held_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("stage1_released_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("stage1_released_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("stage2_released_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("stage2_released_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("stage3_released_cents", sa.BigInteger(), nullable=False, server_default="0"),
            sa.Column("stage3_released_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("status", sa.String(32), nullable=False, server_default="holding"),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        )
        op.create_index("ix_sponsor_escrows_event_id", "sponsor_escrows", ["event_id"])


def downgrade() -> None:
    for table in ("sponsor_escrows", "ticket_escrows", "organizer_bank_accounts",
                  "user_payment_info", "email_templates", "reconciliation_reports",
                  "disputes", "ledger_entries", "email_mock_log"):
        if _table_exists(table):
            op.drop_table(table)
    if _table_exists("payment_mock_ledger"):
        if _column_exists("payment_mock_ledger", "fee_cents"):
            op.drop_column("payment_mock_ledger", "fee_cents")
