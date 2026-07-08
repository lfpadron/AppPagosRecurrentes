"""sync bootstrap devices and id mappings

Revision ID: 0007_sync_bootstrap
Revises: 0006_auth_entitlements
Create Date: 2026-07-06 00:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0007_sync_bootstrap"
down_revision: Union[str, None] = "0006_auth_entitlements"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "payment_instances",
        sa.Column("currency", sa.String(length=3), nullable=False, server_default="MXN"),
    )
    op.create_index("ix_payment_instances_currency", "payment_instances", ["currency"])

    op.create_table(
        "sync_devices",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("device_id", sa.String(length=160), nullable=False),
        sa.Column("platform", sa.String(length=32), nullable=False),
        sa.Column("app_schema_version", sa.Integer(), nullable=True),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_bootstrap_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_sync_devices_user_id", "sync_devices", ["user_id"])
    op.create_index("ix_sync_devices_device_id", "sync_devices", ["device_id"])

    op.create_table(
        "sync_external_ids",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("device_id", sa.String(length=160), nullable=False),
        sa.Column("entity_type", sa.String(length=32), nullable=False),
        sa.Column("local_id", sa.String(length=160), nullable=False),
        sa.Column("server_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "device_id",
            "entity_type",
            "local_id",
            name="uq_sync_external_ids_local",
        ),
    )
    op.create_index("ix_sync_external_ids_user_id", "sync_external_ids", ["user_id"])
    op.create_index("ix_sync_external_ids_device_id", "sync_external_ids", ["device_id"])
    op.create_index("ix_sync_external_ids_entity_type", "sync_external_ids", ["entity_type"])
    op.create_index("ix_sync_external_ids_local_id", "sync_external_ids", ["local_id"])
    op.create_index("ix_sync_external_ids_server_id", "sync_external_ids", ["server_id"])


def downgrade() -> None:
    op.drop_index("ix_sync_external_ids_server_id", table_name="sync_external_ids")
    op.drop_index("ix_sync_external_ids_local_id", table_name="sync_external_ids")
    op.drop_index("ix_sync_external_ids_entity_type", table_name="sync_external_ids")
    op.drop_index("ix_sync_external_ids_device_id", table_name="sync_external_ids")
    op.drop_index("ix_sync_external_ids_user_id", table_name="sync_external_ids")
    op.drop_table("sync_external_ids")
    op.drop_index("ix_sync_devices_device_id", table_name="sync_devices")
    op.drop_index("ix_sync_devices_user_id", table_name="sync_devices")
    op.drop_table("sync_devices")
    op.drop_index("ix_payment_instances_currency", table_name="payment_instances")
    op.drop_column("payment_instances", "currency")
