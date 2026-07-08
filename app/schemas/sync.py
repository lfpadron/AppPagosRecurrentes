from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.enums import (
    Frequency,
    PaymentStatus,
    PaymentType,
    ServiceLifecycleStatus,
    WeekendAdjustment,
)


class SyncStatusResponse(BaseModel):
    user_id: UUID
    is_premium: bool
    server_time: datetime
    service_count: int
    payment_count: int
    device_count: int


class SyncServicePayload(BaseModel):
    id: str
    active: bool = True
    status: ServiceLifecycleStatus = ServiceLifecycleStatus.active
    paused_from: date | None = None
    ended_at: date | None = None
    end_reason: str | None = None
    icon_key: str = "service_default"
    object_name: str
    service_name: str
    provider_name: str
    service_number: str = ""
    provider_url: str | None = None
    is_autopay: bool = False
    charge_account: str | None = None
    initial_cutoff_date: date | None = None
    initial_due_date: date
    weekend_adjustment: WeekendAdjustment = WeekendAdjustment.none
    frequency: Frequency = Frequency.monthly
    interval_count: int = Field(default=1, ge=1)
    estimated_amount: Decimal | None = None
    currency: str = "MXN"
    recurrence_end_date: date | None = None
    recurrence_payment_count: int | None = None
    notes: str | None = None
    version: int = 1
    last_modified_at: datetime | None = None
    last_modified_platform: str | None = None
    last_modified_device_id: str | None = None


class SyncPaymentPayload(BaseModel):
    id: str
    service_account_id: str | None = None
    payment_type: PaymentType
    status: PaymentStatus
    object_name_snapshot: str
    service_name_snapshot: str
    provider_name_snapshot: str
    service_number_snapshot: str = ""
    service_icon_key_snapshot: str = "service_default"
    cutoff_date: date | None = None
    due_date: date
    currency: str = "MXN"
    estimated_amount: Decimal | None = None
    paid_amount: Decimal | None = None
    paid_at: date | None = None
    payment_method: str | None = Field(default=None, max_length=50)
    is_autopay_snapshot: bool = False
    charge_account_snapshot: str | None = None
    receipt_file_id: UUID | None = None
    notes: str | None = None
    generated_by_system: bool = True
    last_modified_at: datetime | None = None
    last_modified_platform: str | None = None
    last_modified_device_id: str | None = None


class SyncBootstrapRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=160)
    platform: str = Field(default="android", max_length=32)
    app_schema_version: int | None = None
    services: list[SyncServicePayload] = Field(default_factory=list)
    payments: list[SyncPaymentPayload] = Field(default_factory=list)


class SyncConflict(BaseModel):
    entity_type: str
    local_id: str
    server_id: UUID
    reason: str
    server_last_modified_at: datetime | None
    local_last_modified_at: datetime | None


class SyncBootstrapResponse(BaseModel):
    imported_services: int
    updated_services: int
    imported_payments: int
    updated_payments: int
    skipped_payments: int
    conflicts: list[SyncConflict]
    service_id_map: dict[str, str]
    payment_id_map: dict[str, str]


class SyncPullResponse(BaseModel):
    services: list[dict[str, Any]]
    payments: list[dict[str, Any]]
