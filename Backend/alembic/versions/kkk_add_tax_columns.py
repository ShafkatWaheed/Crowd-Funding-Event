"""add tax/gateway columns to ticket_sales, sponsor_payments, fundings

Revision ID: kkk_add_tax_columns
Revises: jjj_add_age_restriction
Create Date: 2026-02-27
"""
from alembic import op
import sqlalchemy as sa

revision = "kkk_add_tax_columns"
down_revision = "jjj_add_age_restriction"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("ticket_sales", sa.Column("subtotal_cents", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("ticket_sales", sa.Column("tax_cents", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("ticket_sales", sa.Column("tax_rate", sa.Float(), nullable=False, server_default="0"))
    op.add_column("ticket_sales", sa.Column("tax_jurisdiction", sa.String(32), nullable=False, server_default=""))
    op.add_column("ticket_sales", sa.Column("gateway_transaction_id", sa.String(128), nullable=True))
    op.add_column("ticket_sales", sa.Column("gateway_auth_code", sa.String(64), nullable=True))

    op.add_column("sponsor_payments", sa.Column("subtotal_cents", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("sponsor_payments", sa.Column("tax_cents", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("sponsor_payments", sa.Column("tax_rate", sa.Float(), nullable=False, server_default="0"))
    op.add_column("sponsor_payments", sa.Column("gateway_transaction_id", sa.String(128), nullable=True))
    op.add_column("sponsor_payments", sa.Column("gateway_auth_code", sa.String(64), nullable=True))

    op.add_column("fundings", sa.Column("tax_cents", sa.BigInteger(), nullable=False, server_default="0"))
    op.add_column("fundings", sa.Column("gateway_transaction_id", sa.String(128), nullable=True))
    op.add_column("fundings", sa.Column("gateway_auth_code", sa.String(64), nullable=True))


def downgrade() -> None:
    op.drop_column("fundings", "gateway_auth_code")
    op.drop_column("fundings", "gateway_transaction_id")
    op.drop_column("fundings", "tax_cents")

    op.drop_column("sponsor_payments", "gateway_auth_code")
    op.drop_column("sponsor_payments", "gateway_transaction_id")
    op.drop_column("sponsor_payments", "tax_rate")
    op.drop_column("sponsor_payments", "tax_cents")
    op.drop_column("sponsor_payments", "subtotal_cents")

    op.drop_column("ticket_sales", "gateway_auth_code")
    op.drop_column("ticket_sales", "gateway_transaction_id")
    op.drop_column("ticket_sales", "tax_jurisdiction")
    op.drop_column("ticket_sales", "tax_rate")
    op.drop_column("ticket_sales", "tax_cents")
    op.drop_column("ticket_sales", "subtotal_cents")
