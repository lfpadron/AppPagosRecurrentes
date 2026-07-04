"""payment method and recurrence limits

Revision ID: 0004_pay_method_recur_limits
Revises: 0003_weekend_adjustment
Create Date: 2026-05-22 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0004_pay_method_recur_limits"
down_revision = "0003_weekend_adjustment"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("payment_instances", sa.Column("payment_method", sa.String(length=50), nullable=True))
    op.add_column("service_accounts", sa.Column("recurrence_end_date", sa.Date(), nullable=True))
    op.add_column("service_accounts", sa.Column("recurrence_payment_count", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("service_accounts", "recurrence_payment_count")
    op.drop_column("service_accounts", "recurrence_end_date")
    op.drop_column("payment_instances", "payment_method")
