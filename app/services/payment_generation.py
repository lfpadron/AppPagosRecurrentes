from datetime import date
from uuid import UUID

from sqlmodel import Session, select

from app.core.config import settings
from app.models.base import utc_now
from app.models.enums import (
    PaymentStatus,
    PaymentType,
    RECALCULABLE_STATUSES,
    TERMINAL_STATUSES,
    ServiceLifecycleStatus,
)
from app.models.payment_instance import PaymentInstance
from app.models.service_account import ServiceAccount
from app.models.service_exception import ServiceException
from app.services.date_math import add_months, occurrence_date, adjust_weekend


def _is_exception(due_date: date, exceptions: list[ServiceException]) -> bool:
    return any(exception.start_date <= due_date <= exception.end_date for exception in exceptions)


def _status_by_due_date(
    due_date: date,
    *,
    is_autopay: bool,
    today: date,
    due_soon_days: int,
    upcoming_days: int,
) -> PaymentStatus:
    if is_autopay:
        if due_date < today:
            return PaymentStatus.autopay_pending_confirmation
        days_until_due = (due_date - today).days
        if days_until_due <= due_soon_days:
            return PaymentStatus.autopay_due_soon
        return PaymentStatus.autopay_future

    if due_date < today:
        return PaymentStatus.overdue

    days_until_due = (due_date - today).days
    if days_until_due <= due_soon_days:
        return PaymentStatus.due_soon
    if days_until_due <= upcoming_days:
        return PaymentStatus.upcoming
    return PaymentStatus.future


def _initial_status(
    service: ServiceAccount,
    due_date: date,
    exceptions: list[ServiceException],
    today: date,
) -> PaymentStatus:
    if _is_exception(due_date, exceptions):
        return PaymentStatus.not_applicable_exception
    return _status_by_due_date(
        due_date,
        is_autopay=service.is_autopay,
        today=today,
        due_soon_days=settings.due_soon_days,
        upcoming_days=settings.upcoming_days,
    )


def _existing_recurring_payment(session: Session, service_id: UUID, due_date: date) -> PaymentInstance | None:
    statement = (
        select(PaymentInstance)
        .where(PaymentInstance.service_account_id == service_id)
        .where(PaymentInstance.payment_type == PaymentType.recurring)
        .where(PaymentInstance.due_date == due_date)
        .where(PaymentInstance.status != PaymentStatus.cancelled_by_recalculation)
        .where(PaymentInstance.status != PaymentStatus.cancelled)
    )
    return session.exec(statement).first()


def generate_payments_for_service(
    session: Session,
    service: ServiceAccount,
    start_date: date | None = None,
    horizon_months: int | None = None,
    until_date: date | None = None,
    today: date | None = None,
) -> list[PaymentInstance]:
    if not service.active or service.status != ServiceLifecycleStatus.active:
        return []

    today = today or date.today()
    horizon_months = horizon_months or settings.generation_horizon_months
    horizon_until = until_date or add_months(today, horizon_months)
    if service.recurrence_end_date and service.recurrence_end_date < horizon_until:
        horizon_until = service.recurrence_end_date
    start = start_date or adjust_weekend(service.initial_due_date, service.weekend_adjustment)
    exceptions = session.exec(
        select(ServiceException).where(ServiceException.service_account_id == service.id)
    ).all()

    created: list[PaymentInstance] = []
    occurrence_index = 0
    while True:
        due_date = occurrence_date(
            service.initial_due_date,
            service.frequency,
            service.interval_count,
            occurrence_index,
        )
        due_date = adjust_weekend(due_date, service.weekend_adjustment)
        if due_date > horizon_until:
            break
        if service.recurrence_payment_count is not None and occurrence_index >= service.recurrence_payment_count:
            break

        if due_date >= start and not _existing_recurring_payment(session, service.id, due_date):
            cutoff_date = (
                occurrence_date(
                    service.initial_cutoff_date,
                    service.frequency,
                    service.interval_count,
                    occurrence_index,
                )
                if service.initial_cutoff_date
                else None
            )
            payment = PaymentInstance(
                user_id=service.user_id,
                service_account_id=service.id,
                payment_type=PaymentType.recurring,
                status=_initial_status(service, due_date, exceptions, today),
                object_name_snapshot=service.object_name,
                service_name_snapshot=service.service_name,
                provider_name_snapshot=service.provider_name,
                service_number_snapshot=service.service_number,
                service_icon_key_snapshot=service.icon_key,
                cutoff_date=cutoff_date,
                due_date=due_date,
                currency=service.currency,
                estimated_amount=service.estimated_amount,
                is_autopay_snapshot=service.is_autopay,
                charge_account_snapshot=service.charge_account,
                generated_by_system=True,
                notes=service.notes,
            )
            now = utc_now()
            payment.updated_at = now
            payment.last_modified_at = now
            payment.last_modified_platform = "server"
            session.add(payment)
            created.append(payment)

        occurrence_index += 1

    session.flush()
    return created


def cancel_recalculable_payments(
    session: Session,
    service_id: UUID,
    from_date: date,
) -> list[PaymentInstance]:
    statement = (
        select(PaymentInstance)
        .where(PaymentInstance.service_account_id == service_id)
        .where(PaymentInstance.payment_type == PaymentType.recurring)
        .where(PaymentInstance.due_date >= from_date)
        .where(PaymentInstance.status.in_(list(RECALCULABLE_STATUSES)))
    )
    payments = session.exec(statement).all()
    now = utc_now()
    for payment in payments:
        payment.status = PaymentStatus.cancelled_by_recalculation
        payment.updated_at = now
        payment.last_modified_at = now
        payment.last_modified_platform = "server"
        session.add(payment)
    session.flush()
    return payments


def refresh_payment_status(payment: PaymentInstance, today: date | None = None) -> bool:
    today = today or date.today()
    if payment.status in TERMINAL_STATUSES:
        return False

    if payment.paid_at:
        next_status = PaymentStatus.paid
    else:
        next_status = _status_by_due_date(
            payment.due_date,
            is_autopay=payment.is_autopay_snapshot,
            today=today,
            due_soon_days=settings.due_soon_days,
            upcoming_days=settings.upcoming_days,
        )

    if next_status != payment.status:
        now = utc_now()
        payment.status = next_status
        payment.updated_at = now
        payment.last_modified_at = now
        payment.last_modified_platform = "server"
        return True
    return False


def apply_exception_to_existing_payments(
    session: Session,
    service_id: UUID,
    start_date: date,
    end_date: date,
) -> list[PaymentInstance]:
    mutable_statuses = [
        PaymentStatus.future,
        PaymentStatus.pending,
        PaymentStatus.upcoming,
        PaymentStatus.due_soon,
        PaymentStatus.active,
        PaymentStatus.autopay_due_soon,
        PaymentStatus.autopay_future,
        PaymentStatus.autopay_pending_confirmation,
        PaymentStatus.overdue,
        PaymentStatus.autopay_overdue_confirmation,
    ]
    statement = (
        select(PaymentInstance)
        .where(PaymentInstance.service_account_id == service_id)
        .where(PaymentInstance.due_date >= start_date)
        .where(PaymentInstance.due_date <= end_date)
        .where(PaymentInstance.status.in_(mutable_statuses))
    )
    payments = session.exec(statement).all()
    now = utc_now()
    for payment in payments:
        payment.status = PaymentStatus.not_applicable_exception
        payment.updated_at = now
        payment.last_modified_at = now
        payment.last_modified_platform = "server"
        session.add(payment)
    session.flush()
    return payments
