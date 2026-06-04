from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import Any
from uuid import UUID

from sqlmodel import Session

from app.models.base import utc_now
from app.models.service_account import ServiceAccount
from app.models.service_version import ServiceVersion
from app.services.payment_generation import cancel_recalculable_payments, generate_payments_for_service


def _json_value(value: Any) -> Any:
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    return value


def service_snapshot(service: ServiceAccount) -> dict[str, Any]:
    fields = [
        "id",
        "user_id",
        "active",
        "status",
        "paused_from",
        "ended_at",
        "end_reason",
        "icon_key",
        "object_name",
        "service_name",
        "provider_name",
        "service_number",
        "provider_url",
        "is_autopay",
        "charge_account",
        "initial_cutoff_date",
        "initial_due_date",
        "weekend_adjustment",
        "frequency",
        "interval_count",
        "estimated_amount",
        "currency",
        "recurrence_end_date",
        "recurrence_payment_count",
        "notes",
        "created_at",
        "updated_at",
        "version",
        "last_modified_at",
        "last_modified_platform",
        "last_modified_device_id",
    ]
    return {field: _json_value(getattr(service, field)) for field in fields}


def update_service_and_recalculate(
    session: Session,
    service: ServiceAccount,
    updates: dict[str, Any],
    effective_from: date,
    change_reason: str | None = None,
    horizon_months: int | None = None,
    until_date: date | None = None,
    today: date | None = None,
) -> ServiceAccount:
    version = ServiceVersion(
        service_account_id=service.id,
        version_number=service.version,
        snapshot_json=service_snapshot(service),
        change_reason=change_reason,
        effective_from=effective_from,
    )
    session.add(version)

    for field, value in updates.items():
        setattr(service, field, value)
    now = utc_now()
    service.version += 1
    service.updated_at = now
    service.last_modified_at = now
    service.last_modified_platform = "server"
    session.add(service)
    session.flush()

    cancel_recalculable_payments(session, service.id, effective_from)
    generate_payments_for_service(
        session,
        service,
        start_date=effective_from,
        horizon_months=horizon_months,
        until_date=until_date,
        today=today,
    )
    return service
