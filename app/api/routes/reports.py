from datetime import date
from decimal import Decimal
from io import BytesIO
from uuid import UUID

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from openpyxl import Workbook
from sqlmodel import Session, select

from app.api.deps import get_current_user_id
from app.db.session import get_session
from app.models.enums import OPEN_PAYMENT_STATUSES, PaymentStatus
from app.models.payment_instance import PaymentInstance
from app.schemas.reports import ReportSummary
from app.services.payment_generation import refresh_payment_status

router = APIRouter(prefix="/reports", tags=["reports"])


def _summary(
    *,
    payments: list[PaymentInstance],
    start_date: date,
    end_date: date,
    service_account_id: UUID | None,
    amount_field: str,
) -> ReportSummary:
    total = Decimal("0")
    totals_by_status: dict[str, Decimal] = {}
    for payment in payments:
        amount = getattr(payment, amount_field) or Decimal("0")
        total += amount
        status_value = payment.status.value if hasattr(payment.status, "value") else str(payment.status)
        totals_by_status[status_value] = totals_by_status.get(status_value, Decimal("0")) + amount

    return ReportSummary(
        start_date=start_date,
        end_date=end_date,
        service_account_id=service_account_id,
        payment_count=len(payments),
        total_amount=total,
        totals_by_status=totals_by_status,
    )


@router.get("/paid-summary", response_model=ReportSummary)
def paid_summary(
    start_date: date,
    end_date: date,
    service_account_id: UUID | None = None,
    object_name: str | None = None,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> ReportSummary:
    statement = (
        select(PaymentInstance)
        .where(PaymentInstance.user_id == user_id)
        .where(PaymentInstance.status == PaymentStatus.paid)
        .where(PaymentInstance.due_date >= start_date)
        .where(PaymentInstance.due_date <= end_date)
    )
    if service_account_id:
        statement = statement.where(PaymentInstance.service_account_id == service_account_id)
    if object_name:
        statement = statement.where(PaymentInstance.object_name_snapshot.ilike(f"%{object_name}%"))
    payments = session.exec(statement).all()
    return _summary(
        payments=payments,
        start_date=start_date,
        end_date=end_date,
        service_account_id=service_account_id,
        amount_field="paid_amount",
    )


@router.get("/estimated-summary", response_model=ReportSummary)
def estimated_summary(
    start_date: date,
    end_date: date,
    service_account_id: UUID | None = None,
    object_name: str | None = None,
    include_cancelled: bool = False,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> ReportSummary:
    statement = (
        select(PaymentInstance)
        .where(PaymentInstance.user_id == user_id)
        .where(PaymentInstance.due_date >= start_date)
        .where(PaymentInstance.due_date <= end_date)
    )
    if service_account_id:
        statement = statement.where(PaymentInstance.service_account_id == service_account_id)
    if object_name:
        statement = statement.where(PaymentInstance.object_name_snapshot.ilike(f"%{object_name}%"))
    if not include_cancelled:
        statement = statement.where(PaymentInstance.status != PaymentStatus.cancelled)
        statement = statement.where(PaymentInstance.status != PaymentStatus.cancelled_by_recalculation)
    payments = session.exec(statement).all()

    changed = False
    for payment in payments:
        payment_changed = refresh_payment_status(payment)
        changed = payment_changed or changed
        if payment_changed:
            session.add(payment)
    if changed:
        session.commit()

    open_payments = [
        payment
        for payment in payments
        if payment.status in OPEN_PAYMENT_STATUSES
        or (include_cancelled and payment.status in {PaymentStatus.cancelled, PaymentStatus.cancelled_by_recalculation})
    ]
    return _summary(
        payments=open_payments,
        start_date=start_date,
        end_date=end_date,
        service_account_id=service_account_id,
        amount_field="estimated_amount",
    )


@router.get("/export-excel")
def export_excel(
    start_date: date | None = None,
    end_date: date | None = None,
    object_name: str | None = None,
    include_cancelled: bool = False,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> StreamingResponse:
    statement = select(PaymentInstance).where(PaymentInstance.user_id == user_id)
    if start_date:
        statement = statement.where(PaymentInstance.due_date >= start_date)
    if end_date:
        statement = statement.where(PaymentInstance.due_date <= end_date)
    if object_name:
        statement = statement.where(PaymentInstance.object_name_snapshot.ilike(f"%{object_name}%"))
    if not include_cancelled:
        statement = statement.where(PaymentInstance.status != PaymentStatus.cancelled)
        statement = statement.where(PaymentInstance.status != PaymentStatus.cancelled_by_recalculation)
    statement = statement.order_by(PaymentInstance.due_date)
    payments = session.exec(statement).all()

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Pagos"
    sheet.append(
        [
            "id",
            "objeto",
            "servicio",
            "proveedor",
            "tipo",
            "estado",
            "fecha_limite",
            "monto_estimado",
            "monto_pagado",
            "fecha_pago",
        ]
    )
    for payment in payments:
        sheet.append(
            [
                str(payment.id),
                payment.object_name_snapshot,
                payment.service_name_snapshot,
                payment.provider_name_snapshot,
                payment.payment_type.value,
                payment.status.value,
                payment.due_date.isoformat(),
                float(payment.estimated_amount or 0),
                float(payment.paid_amount or 0),
                payment.paid_at.isoformat() if payment.paid_at else "",
            ]
        )

    buffer = BytesIO()
    workbook.save(buffer)
    buffer.seek(0)
    headers = {"Content-Disposition": "attachment; filename=pagos.xlsx"}
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers=headers,
    )
