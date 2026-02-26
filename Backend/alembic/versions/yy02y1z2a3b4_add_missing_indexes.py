"""Add missing single-column and composite indexes for query performance.

Revision ID: yy02y1z2a3b4
Revises: xx01x0y1z2a3
Create Date: 2026-02-25

"""
from alembic import op

revision = "yy02y1z2a3b4"
down_revision = "xx01x0y1z2a3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Single-column indexes on high-traffic filter columns
    op.create_index("ix_ticket_sales_status", "ticket_sales", ["status"])
    op.create_index("ix_fundings_status", "fundings", ["status"])
    op.create_index("ix_sponsor_bids_category_id", "sponsor_bids", ["category_id"])
    op.create_index("ix_sponsor_bids_sponsor_user_id", "sponsor_bids", ["sponsor_user_id"])
    op.create_index("ix_sponsor_bids_status", "sponsor_bids", ["status"])
    op.create_index("ix_sponsor_tickets_event_id", "sponsor_tickets", ["event_id"])
    op.create_index("ix_sponsor_tickets_sponsor_user_id", "sponsor_tickets", ["sponsor_user_id"])
    op.create_index("ix_sponsor_payments_status", "sponsor_payments", ["status"])
    op.create_index("ix_sponsorship_categories_organizer_id", "sponsorship_categories", ["organizer_id"])
    op.create_index("ix_bookmarks_user_id", "bookmarks", ["user_id"])
    op.create_index("ix_bookmarks_event_id", "bookmarks", ["event_id"])

    # Composite indexes for dashboard aggregate queries
    op.create_index("ix_ticket_sales_event_status", "ticket_sales", ["event_id", "status"])
    op.create_index("ix_ticket_sales_event_created", "ticket_sales", ["event_id", "created_at"])
    op.create_index("ix_fundings_event_status", "fundings", ["event_id", "status"])
    op.create_index("ix_fundings_event_created", "fundings", ["event_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_fundings_event_created", table_name="fundings")
    op.drop_index("ix_fundings_event_status", table_name="fundings")
    op.drop_index("ix_ticket_sales_event_created", table_name="ticket_sales")
    op.drop_index("ix_ticket_sales_event_status", table_name="ticket_sales")
    op.drop_index("ix_bookmarks_event_id", table_name="bookmarks")
    op.drop_index("ix_bookmarks_user_id", table_name="bookmarks")
    op.drop_index("ix_sponsorship_categories_organizer_id", table_name="sponsorship_categories")
    op.drop_index("ix_sponsor_payments_status", table_name="sponsor_payments")
    op.drop_index("ix_sponsor_tickets_sponsor_user_id", table_name="sponsor_tickets")
    op.drop_index("ix_sponsor_tickets_event_id", table_name="sponsor_tickets")
    op.drop_index("ix_sponsor_bids_status", table_name="sponsor_bids")
    op.drop_index("ix_sponsor_bids_sponsor_user_id", table_name="sponsor_bids")
    op.drop_index("ix_sponsor_bids_category_id", table_name="sponsor_bids")
    op.drop_index("ix_fundings_status", table_name="fundings")
    op.drop_index("ix_ticket_sales_status", table_name="ticket_sales")
