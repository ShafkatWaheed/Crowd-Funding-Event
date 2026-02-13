"""Phase 9.4: seed community genre platform settings.

Revision ID: u2v3w4x5y6z7
Revises: t1u2v3w4x5y6
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "u2v3w4x5y6z7"
down_revision = "t1u2v3w4x5y6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "INSERT INTO platform_settings (key, value, description) VALUES "
        "('community_max_duration_days', '14', 'Max total days for community events (funding + event)'),"
        "('community_listing_fee_cents', '1000', 'Listing fee for community events ($10)'),"
        "('community_max_ticket_price_cents', '5000', 'Max ticket price for community tiers ($50)'),"
        "('community_funding_commission_override', '', 'Override funding commission for community events (empty = use global)')"
    )


def downgrade() -> None:
    op.execute(
        "DELETE FROM platform_settings WHERE key IN "
        "('community_max_duration_days','community_listing_fee_cents',"
        "'community_max_ticket_price_cents','community_funding_commission_override')"
    )
