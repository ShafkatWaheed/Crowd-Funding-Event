"""Add Stripe integration fields to users, ticket_sales, fundings, sponsor_payments.

Revision ID: zz03_stripe_fields
Revises: zz02_refund_requested
Create Date: 2026-03-01
"""
import sqlalchemy as sa
from alembic import op

revision = "zz03_stripe_fields"
down_revision = "zz02_refund_requested"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── Users: Stripe customer + Connect account IDs ──
    op.add_column("users", sa.Column("stripe_customer_id", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("stripe_connect_account_id", sa.String(255), nullable=True))
    op.create_index("ix_users_stripe_customer_id", "users", ["stripe_customer_id"], unique=True)
    op.create_index("ix_users_stripe_connect_account_id", "users", ["stripe_connect_account_id"], unique=True)

    # ── Ticket sales: PaymentIntent tracking + refund ID ──
    op.add_column("ticket_sales", sa.Column("stripe_payment_intent_id", sa.String(128), nullable=True))
    op.add_column("ticket_sales", sa.Column("gateway_refund_id", sa.String(128), nullable=True))
    op.create_index("ix_ticket_sales_stripe_pi", "ticket_sales", ["stripe_payment_intent_id"], unique=True)

    # ── Fundings (pledges/donations): PaymentIntent tracking + refund ID ──
    op.add_column("fundings", sa.Column("stripe_payment_intent_id", sa.String(128), nullable=True))
    op.add_column("fundings", sa.Column("gateway_refund_id", sa.String(128), nullable=True))
    op.create_index("ix_fundings_stripe_pi", "fundings", ["stripe_payment_intent_id"], unique=True)

    # ── Sponsor payments: PaymentIntent tracking + refund ID ──
    op.add_column("sponsor_payments", sa.Column("stripe_payment_intent_id", sa.String(128), nullable=True))
    op.add_column("sponsor_payments", sa.Column("gateway_refund_id", sa.String(128), nullable=True))
    op.create_index("ix_sponsor_payments_stripe_pi", "sponsor_payments", ["stripe_payment_intent_id"], unique=True)


def downgrade() -> None:
    # ── Sponsor payments ──
    op.drop_index("ix_sponsor_payments_stripe_pi", table_name="sponsor_payments")
    op.drop_column("sponsor_payments", "gateway_refund_id")
    op.drop_column("sponsor_payments", "stripe_payment_intent_id")

    # ── Fundings ──
    op.drop_index("ix_fundings_stripe_pi", table_name="fundings")
    op.drop_column("fundings", "gateway_refund_id")
    op.drop_column("fundings", "stripe_payment_intent_id")

    # ── Ticket sales ──
    op.drop_index("ix_ticket_sales_stripe_pi", table_name="ticket_sales")
    op.drop_column("ticket_sales", "gateway_refund_id")
    op.drop_column("ticket_sales", "stripe_payment_intent_id")

    # ── Users ──
    op.drop_index("ix_users_stripe_connect_account_id", table_name="users")
    op.drop_index("ix_users_stripe_customer_id", table_name="users")
    op.drop_column("users", "stripe_connect_account_id")
    op.drop_column("users", "stripe_customer_id")
