"""Phase 8: co-org permissions, event discounts, customer history, extend approval.

Revision ID: o6p7q8r9s0t1
Revises: n5o6p7q8r9s0
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "o6p7q8r9s0t1"
down_revision = "n5o6p7q8r9s0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Co-organizer permission: 'read' or 'full'
    op.add_column(
        "event_organizers",
        sa.Column("permission", sa.String(10), nullable=False, server_default="read"),
    )

    # 2. Event-level discounts (flexible rules attached to events)
    op.create_table(
        "event_discounts",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False, index=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column(
            "discount_type",
            sa.String(20),
            nullable=False,
        ),  # 'pledge_percent' | 'ticket_percent' | 'fixed_cents'
        sa.Column("value", sa.Integer, nullable=False),  # percent 0-100 or cents
        sa.Column(
            "target",
            sa.String(16),
            nullable=False,
            server_default="all",
        ),  # 'all' | 'pledgers' | 'non_pledgers'
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # 3. Organizer–customer history (auto-populated when ticket is scanned)
    op.create_table(
        "organizer_customer_history",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("organizer_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("customer_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False),
        sa.Column("scanned_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("organizer_id", "customer_id", "event_id", name="uq_org_cust_event"),
    )

    # 4. Pending extension approval
    op.add_column(
        "events",
        sa.Column("pending_extension", sa.JSON, nullable=True),
    )


def downgrade() -> None:
    op.drop_column("events", "pending_extension")
    op.drop_table("organizer_customer_history")
    op.drop_table("event_discounts")
    op.drop_column("event_organizers", "permission")
