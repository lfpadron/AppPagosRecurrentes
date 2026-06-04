from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.enums import PaymentStatus, PaymentType


class PaymentInstanceRead(BaseModel):
    id: UUID
    user_id: UUID
    service_account_id: UUID | None
    payment_type: PaymentType
    status: PaymentStatus
    object_name_snapshot: str
    service_name_snapshot: str
    provider_name_snapshot: str
    service_number_snapshot: str
    service_icon_key_snapshot: str
    cutoff_date: date | None
    due_date: date
    estimated_amount: Decimal | None
    paid_amount: Decimal | None
    paid_at: date | None
    payment_method: str | None
    is_autopay_snapshot: bool
    charge_account_snapshot: str | None
    receipt_file_id: UUID | None
    notes: str | None
    generated_by_system: bool
    created_at: datetime
    updated_at: datetime
    last_modified_at: datetime
    last_modified_platform: str
    last_modified_device_id: str | None

    model_config = ConfigDict(from_attributes=True)


class PaymentUpdate(BaseModel):
    status: PaymentStatus | None = None
    due_date: date | None = None
    cutoff_date: date | None = None
    estimated_amount: Decimal | None = Field(default=None, ge=0)
    paid_amount: Decimal | None = Field(default=None, ge=0)
    paid_at: date | None = None
    payment_method: str | None = Field(default=None, max_length=50)
    notes: str | None = None


class MarkPaidRequest(BaseModel):
    paid_amount: Decimal | None = Field(default=None, ge=0)
    paid_at: date | None = None
    receipt_file_id: UUID | None = None
    payment_method: str | None = Field(default=None, max_length=50)


class OneTimePaymentCreate(BaseModel):
    service_account_id: UUID | None = None
    icon_key: str | None = Field(default=None, max_length=80)
    object_name: str | None = Field(default=None, max_length=160)
    service_name: str | None = Field(default=None, max_length=160)
    provider_name: str | None = Field(default=None, max_length=160)
    service_number: str | None = Field(default=None, max_length=120)
    due_date: date
    cutoff_date: date | None = None
    estimated_amount: Decimal | None = Field(default=None, ge=0)
    currency: str = Field(default="MXN", min_length=3, max_length=3)
    notes: str | None = None

    @model_validator(mode="after")
    def require_snapshot_when_unlinked(self) -> "OneTimePaymentCreate":
        if self.service_account_id is None:
            missing = [
                name
                for name in ("object_name", "service_name", "provider_name")
                if not getattr(self, name)
            ]
            if missing:
                raise ValueError(f"Missing fields for unlinked one-time payment: {', '.join(missing)}")
        return self


class CancelPaymentRequest(BaseModel):
    reason: str | None = None


class CalendarDay(BaseModel):
    date: date
    total_estimated: Decimal
    payments: list[PaymentInstanceRead]


class CalendarResponse(BaseModel):
    start_date: date
    end_date: date
    days: list[CalendarDay]
