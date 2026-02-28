"""Rename bank columns to Canadian banking fields.

routing_number_encrypted -> institution_number_encrypted
swift_code_encrypted -> transit_number_encrypted
bank_name_encrypted -> dropped (not needed for Canadian banking)

Revision ID: zz01_ca_bank
Revises: nnn_create_audit_logs_table
Create Date: 2026-02-28
"""
from alembic import op
from sqlalchemy import inspect as sa_inspect

revision = "zz01_ca_bank"
down_revision = "nnn_create_audit_logs_table"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa_inspect(bind)
    columns = [c["name"] for c in inspector.get_columns("organizer_bank_accounts")]

    # Rename routing_number_encrypted -> institution_number_encrypted
    if "routing_number_encrypted" in columns and "institution_number_encrypted" not in columns:
        op.alter_column(
            "organizer_bank_accounts",
            "routing_number_encrypted",
            new_column_name="institution_number_encrypted",
        )

    # Rename swift_code_encrypted -> transit_number_encrypted (reuse the column)
    if "swift_code_encrypted" in columns and "transit_number_encrypted" not in columns:
        op.alter_column(
            "organizer_bank_accounts",
            "swift_code_encrypted",
            new_column_name="transit_number_encrypted",
            nullable=False,
        )

    # Drop bank_name_encrypted (no longer needed)
    if "bank_name_encrypted" in columns:
        op.drop_column("organizer_bank_accounts", "bank_name_encrypted")


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa_inspect(bind)
    columns = [c["name"] for c in inspector.get_columns("organizer_bank_accounts")]

    import sqlalchemy as sa

    if "bank_name_encrypted" not in columns:
        op.add_column(
            "organizer_bank_accounts",
            sa.Column("bank_name_encrypted", sa.LargeBinary(), nullable=True),
        )

    if "transit_number_encrypted" in columns and "swift_code_encrypted" not in columns:
        op.alter_column(
            "organizer_bank_accounts",
            "transit_number_encrypted",
            new_column_name="swift_code_encrypted",
            nullable=True,
        )

    if "institution_number_encrypted" in columns and "routing_number_encrypted" not in columns:
        op.alter_column(
            "organizer_bank_accounts",
            "institution_number_encrypted",
            new_column_name="routing_number_encrypted",
        )
