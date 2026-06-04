from datetime import date, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import Boolean, Column, Integer, Numeric, String, Text
from sqlmodel import Field, SQLModel

from app.models.base import utc_now
from app.models.enums import Frequency, ServiceLifecycleStatus, WeekendAdjustment


class ServiceAccount(SQLModel, table=True):
    __tablename__ = "service_accounts"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="users.id", index=True, nullable=False)
    active: bool = Field(default=True, sa_column=Column(Boolean, nullable=False))
    status: ServiceLifecycleStatus = Field(
        default=ServiceLifecycleStatus.active,
        sa_column=Column(String(16), nullable=False, index=True),
    )
    paused_from: date | None = Field(default=None, nullable=True)
    ended_at: date | None = Field(default=None, nullable=True)
    end_reason: str | None = Field(default=None, sa_column=Column(Text, nullable=True))
    icon_key: str = Field(default="service_default", sa_column=Column(String(80), nullable=False, index=True))
    object_name: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    service_name: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    provider_name: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    service_number: str = Field(sa_column=Column(String(120), nullable=False))
    provider_url: str | None = Field(default=None, sa_column=Column(String(500), nullable=True))
    is_autopay: bool = Field(default=False, sa_column=Column(Boolean, nullable=False, index=True))
    charge_account: str | None = Field(default=None, sa_column=Column(String(160), nullable=True))
    initial_cutoff_date: date | None = Field(default=None, nullable=True)
    initial_due_date: date = Field(nullable=False, index=True)
    weekend_adjustment: WeekendAdjustment = Field(
        default=WeekendAdjustment.none,
        sa_column=Column(String(20), nullable=False),
    )
    frequency: Frequency = Field(sa_column=Column(String(16), nullable=False))
    interval_count: int = Field(default=1, sa_column=Column(Integer, nullable=False))
    estimated_amount: Decimal | None = Field(default=None, sa_column=Column(Numeric(12, 2), nullable=True))
    currency: str = Field(default="MXN", sa_column=Column(String(3), nullable=False))
    recurrence_end_date: date | None = Field(default=None, nullable=True)
    recurrence_payment_count: int | None = Field(default=None, sa_column=Column(Integer, nullable=True))
    notes: str | None = Field(default=None, sa_column=Column(Text, nullable=True))
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
    updated_at: datetime = Field(default_factory=utc_now, nullable=False)
    version: int = Field(default=1, sa_column=Column(Integer, nullable=False))
    last_modified_at: datetime = Field(default_factory=utc_now, nullable=False)
    last_modified_platform: str = Field(default="server", sa_column=Column(String(24), nullable=False))
    last_modified_device_id: str | None = Field(default=None, sa_column=Column(String(120), nullable=True))
