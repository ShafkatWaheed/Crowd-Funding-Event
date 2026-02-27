"""add KYC verification: user kyc fields + kyc_documents table + notification types

Revision ID: hhh_kyc_verification
Revises: ggg_escrow_bank_guard
Create Date: 2026-02-27
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect as sa_inspect

revision = "hhh_kyc_verification"
down_revision = "ggg_escrow_bank_guard"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa_inspect(conn)
    existing_users_cols = [c["name"] for c in inspector.get_columns("users")]

    if "kyc_status" not in existing_users_cols:
        op.add_column("users", sa.Column("kyc_status", sa.String(20), nullable=False, server_default="not_started"))
    if "kyc_verified_at" not in existing_users_cols:
        op.add_column("users", sa.Column("kyc_verified_at", sa.DateTime(timezone=True), nullable=True))

    existing_tables = inspector.get_table_names()
    if "kyc_documents" not in existing_tables:
        kyc_doc_type = sa.Enum(
            "id_front", "id_back", "proof_of_address", "selfie", "tax_id",
            name="kycdocumenttype",
        )
        kyc_doc_status = sa.Enum("pending", "approved", "rejected", name="kycdocumentstatus")

        op.create_table(
            "kyc_documents",
            sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
            sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
            sa.Column("document_type", kyc_doc_type, nullable=False),
            sa.Column("file_path", sa.String(500), nullable=False),
            sa.Column("mime_type", sa.String(100), nullable=False),
            sa.Column("original_filename", sa.String(255), nullable=False),
            sa.Column("status", kyc_doc_status, nullable=False, server_default="pending"),
            sa.Column("rejection_reason", sa.Text, nullable=True),
            sa.Column("submitted_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("reviewed_by_id", sa.Integer, sa.ForeignKey("users.id"), nullable=True),
        )

    # KYC notification types
    notif_enum_name = "notificationtype"
    new_values = ["kyc_submitted", "kyc_approved", "kyc_rejected"]
    if conn.dialect.name == "postgresql":
        for val in new_values:
            op.execute(f"ALTER TYPE {notif_enum_name} ADD VALUE IF NOT EXISTS '{val}'")


def downgrade() -> None:
    op.drop_table("kyc_documents")
    op.drop_column("users", "kyc_verified_at")
    op.drop_column("users", "kyc_status")
    sa.Enum(name="kycdocumenttype").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="kycdocumentstatus").drop(op.get_bind(), checkfirst=True)
