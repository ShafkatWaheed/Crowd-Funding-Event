"""Create missing PostgreSQL enum types for disputes and payment_mock_ledger tables.

The zz_add_fee_cents_to_mock_ledger migration created these tables with String columns
instead of proper enum types, causing 'type does not exist' errors at query time.

Fixes:
  - disputes.status: String(32) -> disputestatus
  - payment_mock_ledger.status: String(32) -> mockledgerstatus
  - payment_mock_ledger.operation: String(16) -> mockledgeroperation

Revision ID: mmm_create_missing_enum_types
Revises: lll_cast_escrow_status_columns
Create Date: 2026-02-27
"""
from alembic import op
import sqlalchemy as sa

revision = "mmm_create_missing_enum_types"
down_revision = "lll_cast_escrow_status_columns"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()

    # ── 1. disputestatus ──
    sa.Enum(
        "open", "evidence_submitted", "won", "lost",
        name="disputestatus",
    ).create(bind, checkfirst=True)

    op.execute("ALTER TABLE disputes ALTER COLUMN status DROP DEFAULT")
    op.execute(
        "ALTER TABLE disputes ALTER COLUMN status TYPE disputestatus "
        "USING status::disputestatus"
    )
    op.execute("ALTER TABLE disputes ALTER COLUMN status SET DEFAULT 'open'::disputestatus")

    # ── 2. mockledgerstatus ──
    sa.Enum(
        "pending", "processing", "completed", "failed",
        "settlement_pending", "settled",
        name="mockledgerstatus",
    ).create(bind, checkfirst=True)

    op.execute("ALTER TABLE payment_mock_ledger ALTER COLUMN status DROP DEFAULT")
    op.execute(
        "ALTER TABLE payment_mock_ledger ALTER COLUMN status TYPE mockledgerstatus "
        "USING status::mockledgerstatus"
    )
    op.execute(
        "ALTER TABLE payment_mock_ledger ALTER COLUMN status SET DEFAULT 'pending'::mockledgerstatus"
    )

    # ── 3. mockledgeroperation ──
    sa.Enum(
        "charge", "transfer", "refund", "hold", "release",
        name="mockledgeroperation",
    ).create(bind, checkfirst=True)

    op.execute("ALTER TABLE payment_mock_ledger ALTER COLUMN operation DROP DEFAULT")
    op.execute(
        "ALTER TABLE payment_mock_ledger ALTER COLUMN operation TYPE mockledgeroperation "
        "USING operation::mockledgeroperation"
    )


def downgrade() -> None:
    bind = op.get_bind()

    # Reverse operation
    op.execute("ALTER TABLE payment_mock_ledger ALTER COLUMN operation DROP DEFAULT")
    op.execute(
        "ALTER TABLE payment_mock_ledger ALTER COLUMN operation TYPE VARCHAR(16) "
        "USING operation::VARCHAR"
    )
    sa.Enum(name="mockledgeroperation").drop(bind, checkfirst=True)

    # Reverse status
    op.execute("ALTER TABLE payment_mock_ledger ALTER COLUMN status DROP DEFAULT")
    op.execute(
        "ALTER TABLE payment_mock_ledger ALTER COLUMN status TYPE VARCHAR(32) "
        "USING status::VARCHAR"
    )
    op.execute("ALTER TABLE payment_mock_ledger ALTER COLUMN status SET DEFAULT 'pending'")
    sa.Enum(name="mockledgerstatus").drop(bind, checkfirst=True)

    # Reverse disputes
    op.execute("ALTER TABLE disputes ALTER COLUMN status DROP DEFAULT")
    op.execute(
        "ALTER TABLE disputes ALTER COLUMN status TYPE VARCHAR(32) USING status::VARCHAR"
    )
    op.execute("ALTER TABLE disputes ALTER COLUMN status SET DEFAULT 'open'")
    sa.Enum(name="disputestatus").drop(bind, checkfirst=True)
