from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.enums import Frequency, ServiceLifecycleStatus, WeekendAdjustment


class ServiceAccountBase(BaseModel):
    active: bool = True
    status: ServiceLifecycleStatus = ServiceLifecycleStatus.active
    paused_from: date | None = None
    ended_at: date | None = None
    end_reason: str | None = None
    icon_key: str = Field(default="service_default", min_length=1, max_length=80)
    object_name: str = Field(min_length=1, max_length=160)
    service_name: str = Field(min_length=1, max_length=160)
    provider_name: str = Field(min_length=1, max_length=160)
    service_number: str = Field(min_length=1, max_length=120)
    provider_url: str | None = Field(default=None, max_length=500)
    is_autopay: bool = False
    charge_account: str | None = Field(default=None, max_length=160)
    initial_cutoff_date: date | None = None
    initial_due_date: date
    weekend_adjustment: WeekendAdjustment = WeekendAdjustment.none
    frequency: Frequency = Frequency.monthly
    interval_count: int = Field(default=1, ge=1)
    estimated_amount: Decimal | None = Field(default=None, ge=0)
    currency: str = Field(default="MXN", min_length=3, max_length=3)
    recurrence_end_date: date | None = None
    recurrence_payment_count: int | None = Field(default=None, ge=1)
    notes: str | None = None

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.upper()

    @model_validator(mode="after")
    def validate_cutoff(self) -> "ServiceAccountBase":
        if self.initial_cutoff_date and self.initial_cutoff_date > self.initial_due_date:
            raise ValueError("initial_cutoff_date cannot be after initial_due_date")
        return self


class ServiceAccountCreate(ServiceAccountBase):
    pass


class ServiceAccountUpdate(BaseModel):
    active: bool | None = None
    status: ServiceLifecycleStatus | None = None
    paused_from: date | None = None
    ended_at: date | None = None
    end_reason: str | None = None
    icon_key: str | None = Field(default=None, min_length=1, max_length=80)
    object_name: str | None = Field(default=None, min_length=1, max_length=160)
    service_name: str | None = Field(default=None, min_length=1, max_length=160)
    provider_name: str | None = Field(default=None, min_length=1, max_length=160)
    service_number: str | None = Field(default=None, min_length=1, max_length=120)
    provider_url: str | None = Field(default=None, max_length=500)
    is_autopay: bool | None = None
    charge_account: str | None = Field(default=None, max_length=160)
    initial_cutoff_date: date | None = None
    initial_due_date: date | None = None
    weekend_adjustment: WeekendAdjustment | None = None
    frequency: Frequency | None = None
    interval_count: int | None = Field(default=None, ge=1)
    estimated_amount: Decimal | None = Field(default=None, ge=0)
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    recurrence_end_date: date | None = None
    recurrence_payment_count: int | None = Field(default=None, ge=1)
    notes: str | None = None
    effective_from: date | None = None
    change_reason: str | None = None

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str | None) -> str | None:
        return value.upper() if value else value


class ServiceAccountRead(ServiceAccountBase):
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime
    version: int
    last_modified_at: datetime
    last_modified_platform: str
    last_modified_device_id: str | None

    model_config = ConfigDict(from_attributes=True)


class ServiceExceptionCreate(BaseModel):
    start_date: date
    end_date: date
    reason: str | None = None

    @model_validator(mode="after")
    def validate_range(self) -> "ServiceExceptionCreate":
        if self.end_date < self.start_date:
            raise ValueError("end_date cannot be before start_date")
        return self


class ServiceExceptionRead(ServiceExceptionCreate):
    id: UUID
    service_account_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ServiceVersionRead(BaseModel):
    id: UUID
    service_account_id: UUID
    version_number: int
    snapshot_json: dict[str, Any]
    change_reason: str | None
    effective_from: date
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class RegeneratePaymentsRequest(BaseModel):
    start_date: date | None = None
    horizon_months: int | None = Field(default=None, ge=1, le=120)
