"""Add ratings table.

Revision ID: ll90l3m4n5o6
Revises: kk80k2l3m4n5
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "ll90l3m4n5o6"
down_revision: Union[str, None] = "kk80k2l3m4n5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "ratings",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("rater_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("rated_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False),
        sa.Column("direction", sa.Enum(
            "customer_to_event", "customer_to_organizer",
            "organizer_to_sponsor", "sponsor_to_organizer",
            name="ratingdirection",
        ), nullable=False),
        sa.Column("stars", sa.Integer(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("rater_user_id", "event_id", "direction", name="uq_ratings_rater_event_direction"),
    )
    op.create_index("ix_ratings_rater", "ratings", ["rater_user_id"])
    op.create_index("ix_ratings_rated", "ratings", ["rated_user_id"])
    op.create_index("ix_ratings_event", "ratings", ["event_id"])


def downgrade() -> None:
    op.drop_table("ratings")
    op.execute("DROP TYPE IF EXISTS ratingdirection")
