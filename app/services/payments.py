from datetime import date
from decimal import Decimal
from uuid import UUID

from fastapi import HTTPException, status
from sqlmodel import Session

from app.models.base import utc_now
from app.models.enums import PaymentStatus, PaymentType
from app.models.payment_instance import PaymentInstance
from app.models.service_account import ServiceAccount
from app.services.payment_generation import refresh_payment_status


def _mark_server_modified(payment: PaymentInstance) -> None:
    now = utc_now()
    payment.updated_at = now
    payment.last_modified_at = now
    payment.last_modified_platform = "server"


def create_one_time_payment(
    session: Session,
    user_id: UUID,
    due_date: date,
    service: ServiceAccount | None = None,
    object_name: str | None = None,
    service_name: str | None = None,
    provider_name: str | None = None,
    service_number: str | None = None,
    icon_key: str | None = None,
    cutoff_date: date | None = None,
    estimated_amount: Decimal | None = None,
    currency: str = "MXN",
    notes: str | None = None,
) -> PaymentInstance:
    if service:
        object_name = service.object_name
        service_name = service.service_name
        provider_name = service.provider_name
        service_number = service.service_number
        icon_key = service.icon_key

    if not object_name or not service_name or not provider_name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="object_name, service_name and provider_name are required for unlinked one-time payments",
        )

    payment = PaymentInstance(
        user_id=user_id,
        service_account_id=service.id if service else None,
        payment_type=PaymentType.one_time,
        status=PaymentStatus.overdue if due_date < date.today() else PaymentStatus.pending,
        object_name_snapshot=object_name,
        service_name_snapshot=service_name,
        provider_name_snapshot=provider_name,
        service_number_snapshot=service_number or "",
        service_icon_key_snapshot=icon_key or "service_default",
        cutoff_date=cutoff_date,
        due_date=due_date,
        currency=currency,
        estimated_amount=estimated_amount,
        is_autopay_snapshot=False,
        generated_by_system=False,
        notes=notes,
    )
    _mark_server_modified(payment)
    session.add(payment)
    session.flush()
    return payment


def mark_payment_paid(
    session: Session,
    payment: PaymentInstance,
    paid_amount: Decimal | None = None,
    paid_at: date | None = None,
    receipt_file_id: UUID | None = None,
    payment_method: str | None = None,
) -> PaymentInstance:
    if payment.status in {PaymentStatus.cancelled, PaymentStatus.cancelled_by_recalculation}:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Cancelled payments cannot be paid")

    payment.paid_at = paid_at or date.today()
    payment.paid_amount = paid_amount if paid_amount is not None else payment.estimated_amount
    payment.receipt_file_id = receipt_file_id
    payment.payment_method = payment_method
    payment.status = PaymentStatus.paid
    _mark_server_modified(payment)
    session.add(payment)
    session.flush()
    return payment


def unmark_payment_paid(session: Session, payment: PaymentInstance) -> PaymentInstance:
    if payment.status != PaymentStatus.paid:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only paid payments can be unmarked")

    payment.paid_at = None
    payment.paid_amount = None
    payment.receipt_file_id = None
    payment.payment_method = None
    payment.status = PaymentStatus.pending
    refresh_payment_status(payment)
    _mark_server_modified(payment)
    session.add(payment)
    session.flush()
    return payment


def cancel_payment(session: Session, payment: PaymentInstance, reason: str | None = None) -> PaymentInstance:
    if payment.status == PaymentStatus.paid:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Paid payments cannot be cancelled")

    payment.status = PaymentStatus.cancelled
    if reason:
        payment.notes = f"{payment.notes or ''}\nCancel reason: {reason}".strip()
    _mark_server_modified(payment)
    session.add(payment)
    session.flush()
    return payment
