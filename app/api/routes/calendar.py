from collections import defaultdict
from datetime import date
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.api.deps import get_current_user_id
from app.db.session import get_session
from app.models.enums import PaymentStatus
from app.models.payment_instance import PaymentInstance
from app.schemas.payments import CalendarDay, CalendarResponse
from app.services.payment_generation import refresh_payment_status

router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get("", response_model=CalendarResponse)
def get_calendar(
    start_date: date,
    end_date: date,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> CalendarResponse:
    statement = (
        select(PaymentInstance)
        .where(PaymentInstance.user_id == user_id)
        .where(PaymentInstance.due_date >= start_date)
        .where(PaymentInstance.due_date <= end_date)
        .where(PaymentInstance.status != PaymentStatus.cancelled)
        .where(PaymentInstance.status != PaymentStatus.cancelled_by_recalculation)
        .order_by(PaymentInstance.due_date, PaymentInstance.created_at)
    )
    payments = session.exec(statement).all()
    changed = False
    for payment in payments:
        payment_changed = refresh_payment_status(payment)
        changed = payment_changed or changed
        if payment_changed:
            session.add(payment)
    if changed:
        session.commit()

    grouped: dict[date, list[PaymentInstance]] = defaultdict(list)
    for payment in payments:
        grouped[payment.due_date].append(payment)

    days = [
        CalendarDay(
            date=day,
            total_estimated=sum((payment.estimated_amount or Decimal("0")) for payment in day_payments),
            payments=day_payments,
        )
        for day, day_payments in sorted(grouped.items())
    ]
    return CalendarResponse(start_date=start_date, end_date=end_date, days=days)
