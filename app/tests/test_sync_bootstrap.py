from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import UUID

from sqlmodel import Session, select

from app.models.payment_instance import PaymentInstance
from app.models.service_account import ServiceAccount
from app.schemas.sync import SyncBootstrapRequest, SyncPaymentPayload, SyncServicePayload
from app.services.sync import bootstrap_from_device


USER_ID = UUID("00000000-0000-0000-0000-000000000001")


def test_bootstrap_imports_local_services_and_payments(session: Session) -> None:
    payload = _bootstrap_payload()

    result = bootstrap_from_device(session, user_id=USER_ID, payload=payload)

    assert result.imported_services == 1
    assert result.imported_payments == 1
    assert result.conflicts == []
    assert result.service_id_map["local-service-1"]
    assert result.payment_id_map["local-payment-1"]

    service = session.get(ServiceAccount, UUID(result.service_id_map["local-service-1"]))
    payment = session.get(PaymentInstance, UUID(result.payment_id_map["local-payment-1"]))
    assert service is not None
    assert payment is not None
    assert service.currency == "USD"
    assert payment.currency == "USD"
    assert payment.service_account_id == service.id


def test_bootstrap_is_idempotent_for_same_device_and_local_ids(session: Session) -> None:
    payload = _bootstrap_payload()

    first = bootstrap_from_device(session, user_id=USER_ID, payload=payload)
    second = bootstrap_from_device(session, user_id=USER_ID, payload=payload)

    service_count = len(session.exec(select(ServiceAccount)).all())
    payment_count = len(session.exec(select(PaymentInstance)).all())
    assert service_count == 1
    assert payment_count == 1
    assert first.service_id_map == second.service_id_map
    assert first.payment_id_map == second.payment_id_map
    assert second.updated_services == 1
    assert second.updated_payments == 1


def _bootstrap_payload() -> SyncBootstrapRequest:
    modified_at = datetime(2026, 7, 6, 12, 0, tzinfo=timezone.utc)
    return SyncBootstrapRequest(
        device_id="device-android-1",
        platform="android",
        app_schema_version=3,
        services=[
            SyncServicePayload(
                id="local-service-1",
                object_name="casa",
                service_name="ejemplo sync",
                provider_name="proveedor",
                service_number="123",
                initial_due_date=date(2026, 1, 30),
                estimated_amount=Decimal("900.00"),
                currency="USD",
                last_modified_at=modified_at,
                last_modified_platform="android",
                last_modified_device_id="device-android-1",
            )
        ],
        payments=[
            SyncPaymentPayload(
                id="local-payment-1",
                service_account_id="local-service-1",
                payment_type="recurring",
                status="paid",
                object_name_snapshot="casa",
                service_name_snapshot="ejemplo sync",
                provider_name_snapshot="proveedor",
                service_number_snapshot="123",
                due_date=date(2026, 1, 30),
                currency="USD",
                estimated_amount=Decimal("900.00"),
                paid_amount=Decimal("900.00"),
                paid_at=date(2026, 1, 30),
                is_autopay_snapshot=False,
                generated_by_system=True,
                last_modified_at=modified_at,
                last_modified_platform="android",
                last_modified_device_id="device-android-1",
            )
        ],
    )
