"""initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-04-29
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "service_accounts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("object_name", sa.String(length=160), nullable=False),
        sa.Column("service_name", sa.String(length=160), nullable=False),
        sa.Column("provider_name", sa.String(length=160), nullable=False),
        sa.Column("service_number", sa.String(length=120), nullable=False),
        sa.Column("provider_url", sa.String(length=500), nullable=True),
        sa.Column("is_autopay", sa.Boolean(), nullable=False),
        sa.Column("charge_account", sa.String(length=160), nullable=True),
        sa.Column("initial_cutoff_date", sa.Date(), nullable=True),
        sa.Column("initial_due_date", sa.Date(), nullable=False),
        sa.Column("frequency", sa.String(length=16), nullable=False),
        sa.Column("interval_count", sa.Integer(), nullable=False),
        sa.Column("estimated_amount", sa.Numeric(12, 2), nullable=True),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_service_accounts_user_id", "service_accounts", ["user_id"])
    op.create_index("ix_service_accounts_object_name", "service_accounts", ["object_name"])
    op.create_index("ix_service_accounts_service_name", "service_accounts", ["service_name"])
    op.create_index("ix_service_accounts_provider_name", "service_accounts", ["provider_name"])
    op.create_index("ix_service_accounts_is_autopay", "service_accounts", ["is_autopay"])
    op.create_index("ix_service_accounts_initial_due_date", "service_accounts", ["initial_due_date"])

    op.create_table(
        "payment_instances",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("service_account_id", sa.Uuid(), nullable=True),
        sa.Column("payment_type", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("object_name_snapshot", sa.String(length=160), nullable=False),
        sa.Column("service_name_snapshot", sa.String(length=160), nullable=False),
        sa.Column("provider_name_snapshot", sa.String(length=160), nullable=False),
        sa.Column("service_number_snapshot", sa.String(length=120), nullable=False),
        sa.Column("cutoff_date", sa.Date(), nullable=True),
        sa.Column("due_date", sa.Date(), nullable=False),
        sa.Column("estimated_amount", sa.Numeric(12, 2), nullable=True),
        sa.Column("paid_amount", sa.Numeric(12, 2), nullable=True),
        sa.Column("paid_at", sa.Date(), nullable=True),
        sa.Column("is_autopay_snapshot", sa.Boolean(), nullable=False),
        sa.Column("charge_account_snapshot", sa.String(length=160), nullable=True),
        sa.Column("receipt_file_id", sa.Uuid(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("generated_by_system", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["service_account_id"], ["service_accounts.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_payment_instances_user_id", "payment_instances", ["user_id"])
    op.create_index("ix_payment_instances_service_account_id", "payment_instances", ["service_account_id"])
    op.create_index("ix_payment_instances_payment_type", "payment_instances", ["payment_type"])
    op.create_index("ix_payment_instances_status", "payment_instances", ["status"])
    op.create_index("ix_payment_instances_object_name_snapshot", "payment_instances", ["object_name_snapshot"])
    op.create_index("ix_payment_instances_service_name_snapshot", "payment_instances", ["service_name_snapshot"])
    op.create_index("ix_payment_instances_provider_name_snapshot", "payment_instances", ["provider_name_snapshot"])
    op.create_index("ix_payment_instances_due_date", "payment_instances", ["due_date"])
    op.create_index("ix_payment_instances_is_autopay_snapshot", "payment_instances", ["is_autopay_snapshot"])

    op.create_table(
        "service_exceptions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("service_account_id", sa.Uuid(), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["service_account_id"], ["service_accounts.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_service_exceptions_service_account_id", "service_exceptions", ["service_account_id"])
    op.create_index("ix_service_exceptions_start_date", "service_exceptions", ["start_date"])
    op.create_index("ix_service_exceptions_end_date", "service_exceptions", ["end_date"])

    op.create_table(
        "service_versions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("service_account_id", sa.Uuid(), nullable=False),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("snapshot_json", sa.JSON(), nullable=False),
        sa.Column("change_reason", sa.Text(), nullable=True),
        sa.Column("effective_from", sa.Date(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["service_account_id"], ["service_accounts.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_service_versions_service_account_id", "service_versions", ["service_account_id"])
    op.create_index("ix_service_versions_version_number", "service_versions", ["version_number"])
    op.create_index("ix_service_versions_effective_from", "service_versions", ["effective_from"])

    op.create_table(
        "attachments",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("payment_instance_id", sa.Uuid(), nullable=False),
        sa.Column("file_name", sa.String(length=255), nullable=False),
        sa.Column("file_url", sa.String(length=1000), nullable=False),
        sa.Column("mime_type", sa.String(length=120), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["payment_instance_id"], ["payment_instances.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_attachments_user_id", "attachments", ["user_id"])
    op.create_index("ix_attachments_payment_instance_id", "attachments", ["payment_instance_id"])


def downgrade() -> None:
    op.drop_table("attachments")
    op.drop_table("service_versions")
    op.drop_table("service_exceptions")
    op.drop_table("payment_instances")
    op.drop_table("service_accounts")
    op.drop_table("users")
