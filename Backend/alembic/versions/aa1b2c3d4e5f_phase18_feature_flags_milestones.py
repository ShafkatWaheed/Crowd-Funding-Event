"""Phase 18: Feature flags + Funding milestones tables.

Revision ID: aa1b2c3d4e5f
Revises: z7a8b9c0d1e2
Create Date: 2026-02-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "aa1b2c3d4e5f"
down_revision: Union[str, None] = "z7a8b9c0d1e2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- Phase 18a: Seed feature flag settings ---
    op.execute(
        "INSERT INTO platform_settings (key, value, description) VALUES "
        "('feature_milestones_enabled', 'true', 'Enable Funding Milestones feature (Phase 18)'),"
        "('feature_schedule_enabled', 'true', 'Enable Event Schedule feature (Phase 19)'),"
        "('feature_sponsors_enabled', 'true', 'Enable Sponsor Marketplace feature (Phase 20)') "
        "ON CONFLICT (key) DO NOTHING"
    )

    # --- Phase 18: FundingMilestone table ---
    op.create_table(
        "funding_milestones",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("event_id", sa.Integer, sa.ForeignKey("events.id"), nullable=False, index=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("unlock_percent", sa.Integer, nullable=False),
        sa.Column("benefit_description", sa.Text, nullable=True),
        sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
        sa.Column("like_count", sa.Integer, nullable=False, server_default="0"),
        sa.Column("dislike_count", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # --- Phase 18: MilestoneReaction table ---
    op.create_table(
        "milestone_reactions",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("milestone_id", sa.Integer, sa.ForeignKey("funding_milestones.id"), nullable=False, index=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("reaction", sa.String(10), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("milestone_id", "user_id", name="uq_milestone_reactions_milestone_user"),
    )


def downgrade() -> None:
    op.drop_table("milestone_reactions")
    op.drop_table("funding_milestones")
    op.execute(
        "DELETE FROM platform_settings WHERE key IN "
        "('feature_milestones_enabled','feature_schedule_enabled','feature_sponsors_enabled')"
    )
