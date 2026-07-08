from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlmodel import Session, select

from app.models.base import utc_now
from app.models.payment_instance import PaymentInstance
from app.models.service_account import ServiceAccount
from app.models.sync_device import SyncDevice
from app.models.sync_external_id import SyncExternalId
from app.schemas.sync import (
    SyncBootstrapRequest,
    SyncBootstrapResponse,
    SyncConflict,
    SyncPaymentPayload,
    SyncServicePayload,
)


def bootstrap_from_device(
    session: Session,
    *,
    user_id: UUID,
    payload: SyncBootstrapRequest,
) -> SyncBootstrapResponse:
    device = _touch_device(session, user_id=user_id, payload=payload)
    service_id_map: dict[str, str] = {}
    payment_id_map: dict[str, str] = {}
    conflicts: list[SyncConflict] = []
    imported_services = 0
    updated_services = 0
    imported_payments = 0
    updated_payments = 0
    skipped_payments = 0

    for service_payload in payload.services:
        service, action, conflict = _upsert_service(
            session,
            user_id=user_id,
            device_id=payload.device_id,
            payload=service_payload,
        )
        if service is not None:
            service_id_map[service_payload.id] = str(service.id)
        if action == "created":
            imported_services += 1
        elif action == "updated":
            updated_services += 1
        if conflict is not None:
            conflicts.append(conflict)

    session.flush()

    for payment_payload in payload.payments:
        payment, action, conflict = _upsert_payment(
            session,
            user_id=user_id,
            device_id=payload.device_id,
            service_id_map=service_id_map,
            payload=payment_payload,
        )
        if payment is not None:
            payment_id_map[payment_payload.id] = str(payment.id)
        if action == "created":
            imported_payments += 1
        elif action == "updated":
            updated_payments += 1
        elif action == "skipped":
            skipped_payments += 1
        if conflict is not None:
            conflicts.append(conflict)

    now = utc_now()
    device.last_bootstrap_at = now
    device.updated_at = now
    session.add(device)
    session.commit()

    return SyncBootstrapResponse(
        imported_services=imported_services,
        updated_services=updated_services,
        imported_payments=imported_payments,
        updated_payments=updated_payments,
        skipped_payments=skipped_payments,
        conflicts=conflicts,
        service_id_map=service_id_map,
        payment_id_map=payment_id_map,
    )


def _touch_device(
    session: Session,
    *,
    user_id: UUID,
    payload: SyncBootstrapRequest,
) -> SyncDevice:
    statement = (
        select(SyncDevice)
        .where(SyncDevice.user_id == user_id)
        .where(SyncDevice.device_id == payload.device_id)
    )
    device = session.exec(statement).first()
    now = utc_now()
    if device is None:
        device = SyncDevice(
            user_id=user_id,
            device_id=payload.device_id,
            platform=payload.platform,
            app_schema_version=payload.app_schema_version,
            created_at=now,
        )
    device.platform = payload.platform
    device.app_schema_version = payload.app_schema_version
    device.last_seen_at = now
    device.updated_at = now
    session.add(device)
    session.flush()
    return device


def _upsert_service(
    session: Session,
    *,
    user_id: UUID,
    device_id: str,
    payload: SyncServicePayload,
) -> tuple[ServiceAccount | None, str, SyncConflict | None]:
    server_id = _server_id_for_local(
        session,
        user_id=user_id,
        device_id=device_id,
        entity_type="service",
        local_id=payload.id,
    )
    service = session.get(ServiceAccount, server_id) if server_id else None
    if service is None:
        service = ServiceAccount(
            id=_uuid_or_new(payload.id),
            user_id=user_id,
            **_service_data(payload),
        )
        _apply_sync_metadata(service, payload.last_modified_at, payload.last_modified_platform, payload.last_modified_device_id)
        session.add(service)
        session.flush()
        _remember_mapping(
            session,
            user_id=user_id,
            device_id=device_id,
            entity_type="service",
            local_id=payload.id,
            server_id=service.id,
        )
        return service, "created", None

    if _server_is_newer(service.last_modified_at, payload.last_modified_at):
        _remember_mapping(
            session,
            user_id=user_id,
            device_id=device_id,
            entity_type="service",
            local_id=payload.id,
            server_id=service.id,
        )
        return service, "conflict", _conflict("service", payload.id, service.id, service.last_modified_at, payload.last_modified_at)

    for field, value in _service_data(payload).items():
        setattr(service, field, value)
    service.version = max(service.version, payload.version)
    service.updated_at = utc_now()
    _apply_sync_metadata(service, payload.last_modified_at, payload.last_modified_platform, payload.last_modified_device_id)
    session.add(service)
    _remember_mapping(
        session,
        user_id=user_id,
        device_id=device_id,
        entity_type="service",
        local_id=payload.id,
        server_id=service.id,
    )
    return service, "updated", None


def _upsert_payment(
    session: Session,
    *,
    user_id: UUID,
    device_id: str,
    service_id_map: dict[str, str],
    payload: SyncPaymentPayload,
) -> tuple[PaymentInstance | None, str, SyncConflict | None]:
    server_id = _server_id_for_local(
        session,
        user_id=user_id,
        device_id=device_id,
        entity_type="payment",
        local_id=payload.id,
    )
    payment = session.get(PaymentInstance, server_id) if server_id else None
    service_account_id = _mapped_service_id(
        session,
        user_id=user_id,
        device_id=device_id,
        service_id_map=service_id_map,
        local_service_id=payload.service_account_id,
    )
    if payload.service_account_id is not None and service_account_id is None:
        return None, "skipped", None

    if payment is None:
        payment = PaymentInstance(
            id=_uuid_or_new(payload.id),
            user_id=user_id,
            service_account_id=service_account_id,
            **_payment_data(payload),
        )
        _apply_sync_metadata(payment, payload.last_modified_at, payload.last_modified_platform, payload.last_modified_device_id)
        session.add(payment)
        session.flush()
        _remember_mapping(
            session,
            user_id=user_id,
            device_id=device_id,
            entity_type="payment",
            local_id=payload.id,
            server_id=payment.id,
        )
        return payment, "created", None

    if _server_is_newer(payment.last_modified_at, payload.last_modified_at):
        _remember_mapping(
            session,
            user_id=user_id,
            device_id=device_id,
            entity_type="payment",
            local_id=payload.id,
            server_id=payment.id,
        )
        return payment, "conflict", _conflict("payment", payload.id, payment.id, payment.last_modified_at, payload.last_modified_at)

    payment.service_account_id = service_account_id
    for field, value in _payment_data(payload).items():
        setattr(payment, field, value)
    payment.updated_at = utc_now()
    _apply_sync_metadata(payment, payload.last_modified_at, payload.last_modified_platform, payload.last_modified_device_id)
    session.add(payment)
    _remember_mapping(
        session,
        user_id=user_id,
        device_id=device_id,
        entity_type="payment",
        local_id=payload.id,
        server_id=payment.id,
    )
    return payment, "updated", None


def _service_data(payload: SyncServicePayload) -> dict:
    return {
        "active": payload.active,
        "status": payload.status,
        "paused_from": payload.paused_from,
        "ended_at": payload.ended_at,
        "end_reason": payload.end_reason,
        "icon_key": payload.icon_key,
        "object_name": payload.object_name,
        "service_name": payload.service_name,
        "provider_name": payload.provider_name,
        "service_number": payload.service_number,
        "provider_url": payload.provider_url,
        "is_autopay": payload.is_autopay,
        "charge_account": payload.charge_account,
        "initial_cutoff_date": payload.initial_cutoff_date,
        "initial_due_date": payload.initial_due_date,
        "weekend_adjustment": payload.weekend_adjustment,
        "frequency": payload.frequency,
        "interval_count": payload.interval_count,
        "estimated_amount": payload.estimated_amount,
        "currency": payload.currency.upper(),
        "recurrence_end_date": payload.recurrence_end_date,
        "recurrence_payment_count": payload.recurrence_payment_count,
        "notes": payload.notes,
        "version": payload.version,
    }


def _payment_data(payload: SyncPaymentPayload) -> dict:
    return {
        "payment_type": payload.payment_type,
        "status": payload.status,
        "object_name_snapshot": payload.object_name_snapshot,
        "service_name_snapshot": payload.service_name_snapshot,
        "provider_name_snapshot": payload.provider_name_snapshot,
        "service_number_snapshot": payload.service_number_snapshot,
        "service_icon_key_snapshot": payload.service_icon_key_snapshot,
        "cutoff_date": payload.cutoff_date,
        "due_date": payload.due_date,
        "currency": payload.currency.upper(),
        "estimated_amount": payload.estimated_amount,
        "paid_amount": payload.paid_amount,
        "paid_at": payload.paid_at,
        "payment_method": payload.payment_method,
        "is_autopay_snapshot": payload.is_autopay_snapshot,
        "charge_account_snapshot": payload.charge_account_snapshot,
        "receipt_file_id": payload.receipt_file_id,
        "notes": payload.notes,
        "generated_by_system": payload.generated_by_system,
    }


def _server_id_for_local(
    session: Session,
    *,
    user_id: UUID,
    device_id: str,
    entity_type: str,
    local_id: str,
) -> UUID | None:
    local_uuid = _uuid_or_none(local_id)
    if local_uuid is not None:
        return local_uuid
    statement = (
        select(SyncExternalId)
        .where(SyncExternalId.user_id == user_id)
        .where(SyncExternalId.device_id == device_id)
        .where(SyncExternalId.entity_type == entity_type)
        .where(SyncExternalId.local_id == local_id)
    )
    mapping = session.exec(statement).first()
    return mapping.server_id if mapping else None


def _remember_mapping(
    session: Session,
    *,
    user_id: UUID,
    device_id: str,
    entity_type: str,
    local_id: str,
    server_id: UUID,
) -> None:
    statement = (
        select(SyncExternalId)
        .where(SyncExternalId.user_id == user_id)
        .where(SyncExternalId.device_id == device_id)
        .where(SyncExternalId.entity_type == entity_type)
        .where(SyncExternalId.local_id == local_id)
    )
    existing = session.exec(statement).first()
    if existing:
        existing.server_id = server_id
        session.add(existing)
        return
    session.add(
        SyncExternalId(
            user_id=user_id,
            device_id=device_id,
            entity_type=entity_type,
            local_id=local_id,
            server_id=server_id,
        )
    )


def _mapped_service_id(
    session: Session,
    *,
    user_id: UUID,
    device_id: str,
    service_id_map: dict[str, str],
    local_service_id: str | None,
) -> UUID | None:
    if local_service_id is None:
        return None
    if local_service_id in service_id_map:
        return UUID(service_id_map[local_service_id])
    return _server_id_for_local(
        session,
        user_id=user_id,
        device_id=device_id,
        entity_type="service",
        local_id=local_service_id,
    )


def _apply_sync_metadata(
    entity,
    last_modified_at: datetime | None,
    platform: str | None,
    device_id: str | None,
) -> None:
    entity.last_modified_at = _aware_utc(last_modified_at) or utc_now()
    entity.last_modified_platform = platform or "android"
    entity.last_modified_device_id = device_id


def _server_is_newer(server_value: datetime | None, local_value: datetime | None) -> bool:
    server_time = _aware_utc(server_value)
    local_time = _aware_utc(local_value)
    return server_time is not None and local_time is not None and server_time > local_time


def _aware_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _uuid_or_none(value: str | None) -> UUID | None:
    if not value:
        return None
    try:
        return UUID(value)
    except ValueError:
        return None


def _uuid_or_new(value: str) -> UUID:
    return _uuid_or_none(value) or uuid4()


def _conflict(
    entity_type: str,
    local_id: str,
    server_id: UUID,
    server_last_modified_at: datetime | None,
    local_last_modified_at: datetime | None,
) -> SyncConflict:
    return SyncConflict(
        entity_type=entity_type,
        local_id=local_id,
        server_id=server_id,
        reason="server_newer",
        server_last_modified_at=server_last_modified_at,
        local_last_modified_at=local_last_modified_at,
    )
