"""Drop unique constraint on sponsor_bids to allow multiple bids per category.

Revision ID: gg40g8h9i0j1
Revises: ff30f6a7b8c9
Create Date: 2026-02-18
"""
from typing import Union
from alembic import op

revision: str = "gg40g8h9i0j1"
down_revision: Union[str, None] = "ff30f6a7b8c9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint("uq_sponsor_bids_category_user", "sponsor_bids", type_="unique")


def downgrade() -> None:
    op.create_unique_constraint(
        "uq_sponsor_bids_category_user",
        "sponsor_bids",
        ["category_id", "sponsor_user_id"],
    )
