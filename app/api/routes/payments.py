from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select

from app.api.deps import get_current_user_id
from app.db.session import get_session
from app.models.base import utc_now
from app.models.enums import PaymentStatus, PaymentType
from app.models.payment_instance import PaymentInstance
from app.models.service_account import ServiceAccount
from app.schemas.payments import (
    CancelPaymentRequest,
    MarkPaidRequest,
    OneTimePaymentCreate,
    PaymentInstanceRead,
    PaymentUpdate,
)
from app.services.payment_generation import refresh_payment_status
from app.services.payments import (
    cancel_payment,
    create_one_time_payment,
    mark_payment_paid,
    unmark_payment_paid,
)

router = APIRouter(prefix="/payments", tags=["payments"])


def _get_payment_or_404(session: Session, payment_id: UUID, user_id: UUID) -> PaymentInstance:
    payment = session.get(PaymentInstance, payment_id)
    if not payment or payment.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    return payment


def _refresh_and_commit(session: Session, payments: list[PaymentInstance]) -> None:
    changed = False
    for payment in payments:
        payment_changed = refresh_payment_status(payment)
        changed = payment_changed or changed
        if payment_changed:
            session.add(payment)
    if changed:
        session.commit()


@router.post("/one-time", response_model=PaymentInstanceRead, status_code=status.HTTP_201_CREATED)
def create_one_time(
    payload: OneTimePaymentCreate,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> PaymentInstance:
    service = None
    if payload.service_account_id:
        service = session.get(ServiceAccount, payload.service_account_id)
        if not service or service.user_id != user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")

    payment = create_one_time_payment(
        session,
        user_id=user_id,
        service=service,
        object_name=payload.object_name,
        service_name=payload.service_name,
        provider_name=payload.provider_name,
        service_number=payload.service_number,
        icon_key=payload.icon_key,
        cutoff_date=payload.cutoff_date,
        due_date=payload.due_date,
        estimated_amount=payload.estimated_amount,
        currency=payload.currency,
        notes=payload.notes,
    )
    session.commit()
    session.refresh(payment)
    return payment


@router.get("", response_model=list[PaymentInstanceRead])
def list_payments(
    start_date: date | None = None,
    end_date: date | None = None,
    object_name: str | None = None,
    service_name: str | None = None,
    provider_name: str | None = None,
    currency: str | None = None,
    is_autopay: bool | None = None,
    active: bool | None = None,
    status_filter: PaymentStatus | None = Query(default=None, alias="status"),
    payment_type: PaymentType | None = None,
    service_account_id: UUID | None = None,
    include_cancelled: bool = False,
    limit: int = Query(default=90, ge=1, le=90),
    offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> list[PaymentInstance]:
    statement = select(PaymentInstance).where(PaymentInstance.user_id == user_id)

    if active is not None:
        statement = statement.join(ServiceAccount, isouter=True).where(ServiceAccount.active == active)
    if service_account_id:
        statement = statement.where(PaymentInstance.service_account_id == service_account_id)
    if start_date:
        statement = statement.where(PaymentInstance.due_date >= start_date)
    if end_date:
        statement = statement.where(PaymentInstance.due_date <= end_date)
    if object_name:
        statement = statement.where(PaymentInstance.object_name_snapshot.ilike(f"%{object_name}%"))
    if service_name:
        statement = statement.where(PaymentInstance.service_name_snapshot.ilike(f"%{service_name}%"))
    if provider_name:
        statement = statement.where(PaymentInstance.provider_name_snapshot.ilike(f"%{provider_name}%"))
    if currency:
        statement = statement.where(PaymentInstance.currency == currency.upper())
    if is_autopay is not None:
        statement = statement.where(PaymentInstance.is_autopay_snapshot == is_autopay)
    if not include_cancelled:
        statement = statement.where(PaymentInstance.status != PaymentStatus.cancelled)
        statement = statement.where(PaymentInstance.status != PaymentStatus.cancelled_by_recalculation)
    if status_filter:
        statement = statement.where(PaymentInstance.status == status_filter)
    if payment_type:
        statement = statement.where(PaymentInstance.payment_type == payment_type)

    statement = statement.order_by(PaymentInstance.due_date, PaymentInstance.created_at).offset(offset).limit(limit)
    payments = session.exec(statement).all()
    _refresh_and_commit(session, payments)
    return payments


@router.get("/{payment_id}", response_model=PaymentInstanceRead)
def get_payment(
    payment_id: UUID,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> PaymentInstance:
    payment = _get_payment_or_404(session, payment_id, user_id)
    if refresh_payment_status(payment):
        session.add(payment)
        session.commit()
        session.refresh(payment)
    return payment


@router.patch("/{payment_id}", response_model=PaymentInstanceRead)
def update_payment(
    payment_id: UUID,
    payload: PaymentUpdate,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> PaymentInstance:
    payment = _get_payment_or_404(session, payment_id, user_id)
    if payment.status == PaymentStatus.paid:
        immutable_fields = {"status", "due_date", "cutoff_date", "estimated_amount", "paid_amount", "paid_at"}
        if immutable_fields.intersection(payload.model_dump(exclude_unset=True)):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Paid payments cannot be modified")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(payment, field, value)
    payment.updated_at = utc_now()
    session.add(payment)
    session.commit()
    session.refresh(payment)
    return payment


@router.post("/{payment_id}/unmark-paid", response_model=PaymentInstanceRead)
def unmark_paid(
    payment_id: UUID,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> PaymentInstance:
    payment = _get_payment_or_404(session, payment_id, user_id)
    unmark_payment_paid(session, payment)
    session.commit()
    session.refresh(payment)
    return payment


@router.post("/{payment_id}/mark-paid", response_model=PaymentInstanceRead)
def mark_paid(
    payment_id: UUID,
    payload: MarkPaidRequest,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> PaymentInstance:
    payment = _get_payment_or_404(session, payment_id, user_id)
    mark_payment_paid(
        session,
        payment,
        paid_amount=payload.paid_amount,
        paid_at=payload.paid_at,
        receipt_file_id=payload.receipt_file_id,
        payment_method=payload.payment_method,
    )
    session.commit()
    session.refresh(payment)
    return payment


@router.post("/{payment_id}/cancel", response_model=PaymentInstanceRead)
def cancel(
    payment_id: UUID,
    payload: CancelPaymentRequest | None = None,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> PaymentInstance:
    payment = _get_payment_or_404(session, payment_id, user_id)
    cancel_payment(session, payment, reason=payload.reason if payload else None)
    session.commit()
    session.refresh(payment)
    return payment
