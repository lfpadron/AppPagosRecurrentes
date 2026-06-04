from datetime import date, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import Boolean, Column, Numeric, String, Text
from sqlmodel import Field, SQLModel

from app.models.base import utc_now
from app.models.enums import PaymentStatus, PaymentType


class PaymentInstance(SQLModel, table=True):
    __tablename__ = "payment_instances"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="users.id", index=True, nullable=False)
    service_account_id: UUID | None = Field(default=None, foreign_key="service_accounts.id", index=True)
    payment_type: PaymentType = Field(sa_column=Column(String(16), nullable=False, index=True))
    status: PaymentStatus = Field(sa_column=Column(String(40), nullable=False, index=True))
    object_name_snapshot: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    service_name_snapshot: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    provider_name_snapshot: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    service_number_snapshot: str = Field(sa_column=Column(String(120), nullable=False))
    service_icon_key_snapshot: str = Field(
        default="service_default",
        sa_column=Column(String(80), nullable=False, index=True),
    )
    cutoff_date: date | None = Field(default=None, nullable=True)
    due_date: date = Field(nullable=False, index=True)
    estimated_amount: Decimal | None = Field(default=None, sa_column=Column(Numeric(12, 2), nullable=True))
    paid_amount: Decimal | None = Field(default=None, sa_column=Column(Numeric(12, 2), nullable=True))
    paid_at: date | None = Field(default=None, nullable=True)
    payment_method: str | None = Field(default=None, sa_column=Column(String(50), nullable=True))
    is_autopay_snapshot: bool = Field(default=False, sa_column=Column(Boolean, nullable=False, index=True))
    charge_account_snapshot: str | None = Field(default=None, sa_column=Column(String(160), nullable=True))
    receipt_file_id: UUID | None = Field(default=None, nullable=True)
    notes: str | None = Field(default=None, sa_column=Column(Text, nullable=True))
    generated_by_system: bool = Field(default=True, sa_column=Column(Boolean, nullable=False))
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
    updated_at: datetime = Field(default_factory=utc_now, nullable=False)
    last_modified_at: datetime = Field(default_factory=utc_now, nullable=False)
    last_modified_platform: str = Field(default="server", sa_column=Column(String(24), nullable=False))
    last_modified_device_id: str | None = Field(default=None, sa_column=Column(String(120), nullable=True))
