"""service weekend adjustment

Revision ID: 0003_weekend_adjustment
Revises: 0002_service_lifecycle_icons
Create Date: 2026-05-11
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0003_weekend_adjustment"
down_revision: Union[str, None] = "0002_service_lifecycle_icons"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "service_accounts",
        sa.Column(
            "weekend_adjustment",
            sa.String(length=20),
            nullable=False,
            server_default="none",
        ),
    )


def downgrade() -> None:
    op.drop_column("service_accounts", "weekend_adjustment")
