"""sync metadata and schema version marker

Revision ID: 0005_sync_metadata_schema_version
Revises: 0004_payment_method_recurrence_limits
Create Date: 2026-06-04 00:00:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0005_sync_metadata_schema_version"
down_revision: Union[str, None] = "0004_payment_method_recurrence_limits"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "app_schema_versions",
        sa.Column("id", sa.String(length=32), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("description", sa.String(length=200), nullable=True),
        sa.Column("applied_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.execute(
        "INSERT INTO app_schema_versions (id, version, description, applied_at) "
        "VALUES ('main', 5, 'sync metadata prep', NOW())"
    )

    for table_name in ("service_accounts", "payment_instances"):
        op.add_column(
            table_name,
            sa.Column("last_modified_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.add_column(
            table_name,
            sa.Column(
                "last_modified_platform",
                sa.String(length=24),
                nullable=True,
            ),
        )
        op.add_column(
            table_name,
            sa.Column("last_modified_device_id", sa.String(length=120), nullable=True),
        )
        op.execute(
            f"UPDATE {table_name} SET "
            "last_modified_at = COALESCE(updated_at, NOW()), "
            "last_modified_platform = 'server' "
            "WHERE last_modified_at IS NULL"
        )
        op.alter_column(table_name, "last_modified_at", nullable=False)
        op.alter_column(table_name, "last_modified_platform", nullable=False)


def downgrade() -> None:
    for table_name in ("payment_instances", "service_accounts"):
        op.drop_column(table_name, "last_modified_device_id")
        op.drop_column(table_name, "last_modified_platform")
        op.drop_column(table_name, "last_modified_at")
    op.drop_table("app_schema_versions")
