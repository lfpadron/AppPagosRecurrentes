"""service lifecycle and icon keys

Revision ID: 0002_service_lifecycle_icons
Revises: 0001_initial
Create Date: 2026-05-06
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0002_service_lifecycle_icons"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "service_accounts",
        sa.Column("status", sa.String(length=16), nullable=False, server_default="active"),
    )
    op.add_column("service_accounts", sa.Column("paused_from", sa.Date(), nullable=True))
    op.add_column("service_accounts", sa.Column("ended_at", sa.Date(), nullable=True))
    op.add_column("service_accounts", sa.Column("end_reason", sa.Text(), nullable=True))
    op.add_column(
        "service_accounts",
        sa.Column("icon_key", sa.String(length=80), nullable=False, server_default="service_default"),
    )
    op.create_index("ix_service_accounts_status", "service_accounts", ["status"])
    op.create_index("ix_service_accounts_icon_key", "service_accounts", ["icon_key"])

    op.add_column(
        "payment_instances",
        sa.Column(
            "service_icon_key_snapshot",
            sa.String(length=80),
            nullable=False,
            server_default="service_default",
        ),
    )
    op.create_index(
        "ix_payment_instances_service_icon_key_snapshot",
        "payment_instances",
        ["service_icon_key_snapshot"],
    )


def downgrade() -> None:
    op.drop_index("ix_payment_instances_service_icon_key_snapshot", table_name="payment_instances")
    op.drop_column("payment_instances", "service_icon_key_snapshot")
    op.drop_index("ix_service_accounts_icon_key", table_name="service_accounts")
    op.drop_index("ix_service_accounts_status", table_name="service_accounts")
    op.drop_column("service_accounts", "icon_key")
    op.drop_column("service_accounts", "end_reason")
    op.drop_column("service_accounts", "ended_at")
    op.drop_column("service_accounts", "paused_from")
    op.drop_column("service_accounts", "status")
