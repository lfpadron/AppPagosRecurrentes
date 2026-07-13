from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from sqlmodel import Session, select

from app.models.enums import (
    Frequency,
    PaymentStatus,
    PaymentType,
    ServiceLifecycleStatus,
    WeekendAdjustment,
)
from app.models.payment_instance import PaymentInstance
from app.models.service_account import ServiceAccount
from app.models.service_exception import ServiceException
from app.api.routes.calendar import get_calendar
from app.api.routes.payments import list_payments, update_payment
from app.api.routes.reports import estimated_summary, paid_summary
from app.schemas.payments import PaymentUpdate
from app.services.payment_generation import generate_payments_for_service
from app.services.payments import (
    cancel_payment,
    create_one_time_payment,
    mark_payment_paid,
    unmark_payment_paid,
)
from app.services.service_accounts import update_service_and_recalculate

USER_ID = UUID("00000000-0000-0000-0000-000000000001")


def _service(
    session: Session,
    *,
    frequency: Frequency = Frequency.monthly,
    interval_count: int = 1,
    initial_due_date: date = date(2026, 1, 15),
    is_autopay: bool = False,
    weekend_adjustment: WeekendAdjustment = WeekendAdjustment.none,
) -> ServiceAccount:
    service = ServiceAccount(
        user_id=USER_ID,
        object_name="Casa",
        service_name="Servicio",
        provider_name="Proveedor",
        service_number="ABC-123",
        icon_key="service_school",
        is_autopay=is_autopay,
        initial_due_date=initial_due_date,
        weekend_adjustment=weekend_adjustment,
        frequency=frequency,
        interval_count=interval_count,
        estimated_amount=Decimal("100.00"),
    )
    session.add(service)
    session.flush()
    return service


def _payments(session: Session) -> list[PaymentInstance]:
    return session.exec(select(PaymentInstance).order_by(PaymentInstance.due_date)).all()


def test_generates_monthly_payments(session: Session) -> None:
    service = _service(session)
    generate_payments_for_service(
        session,
        service,
        until_date=date(2026, 3, 31),
        today=date(2026, 1, 1),
    )
    payments = _payments(session)

    assert [payment.due_date for payment in payments] == [
        date(2026, 1, 15),
        date(2026, 2, 15),
        date(2026, 3, 15),
    ]
    assert {payment.due_date: payment.status for payment in payments} == {
        date(2026, 1, 15): PaymentStatus.upcoming,
        date(2026, 2, 15): PaymentStatus.future,
        date(2026, 3, 15): PaymentStatus.future,
    }
    assert {payment.service_icon_key_snapshot for payment in payments} == {"service_school"}


def test_generates_bimonthly_payments(session: Session) -> None:
    service = _service(session, interval_count=2)
    generate_payments_for_service(
        session,
        service,
        until_date=date(2026, 6, 30),
        today=date(2026, 1, 1),
    )

    assert [payment.due_date for payment in _payments(session)] == [
        date(2026, 1, 15),
        date(2026, 3, 15),
        date(2026, 5, 15),
    ]


def test_generates_yearly_payments(session: Session) -> None:
    service = _service(session, frequency=Frequency.yearly, initial_due_date=date(2026, 5, 10))
    generate_payments_for_service(
        session,
        service,
        until_date=date(2028, 12, 31),
        today=date(2026, 1, 1),
    )

    assert [payment.due_date for payment in _payments(session)] == [
        date(2026, 5, 10),
        date(2027, 5, 10),
        date(2028, 5, 10),
    ]


def test_exceptions_mark_generated_payments_not_applicable(session: Session) -> None:
    service = _service(session)
    session.add(
        ServiceException(
            service_account_id=service.id,
            start_date=date(2026, 2, 1),
            end_date=date(2026, 2, 28),
            reason="Mes sin cobro",
        )
    )
    session.flush()
    generate_payments_for_service(
        session,
        service,
        until_date=date(2026, 3, 31),
        today=date(2026, 1, 1),
    )

    statuses = {payment.due_date: payment.status for payment in _payments(session)}
    assert statuses[date(2026, 2, 15)] == PaymentStatus.not_applicable_exception
    assert statuses[date(2026, 1, 15)] == PaymentStatus.upcoming


def test_classifies_due_soon_upcoming_future_and_autopay(session: Session) -> None:
    service = _service(session, initial_due_date=date(2026, 1, 5))
    generate_payments_for_service(
        session,
        service,
        until_date=date(2026, 1, 25),
        today=date(2026, 1, 1),
    )
    statuses = {payment.due_date: payment.status for payment in _payments(session)}
    assert statuses[date(2026, 1, 5)] == PaymentStatus.due_soon

    autopay_due_soon = _service(
        session,
        initial_due_date=date(2026, 1, 8),
        is_autopay=True,
    )
    generate_payments_for_service(
        session,
        autopay_due_soon,
        until_date=date(2026, 1, 8),
        today=date(2026, 1, 1),
    )
    autopay_due_soon_payment = session.exec(
        select(PaymentInstance).where(
            PaymentInstance.service_account_id == autopay_due_soon.id
        )
    ).one()
    assert autopay_due_soon_payment.status == PaymentStatus.autopay_due_soon

    autopay_future = _service(
        session,
        initial_due_date=date(2026, 1, 9),
        is_autopay=True,
    )
    generate_payments_for_service(
        session,
        autopay_future,
        until_date=date(2026, 1, 9),
        today=date(2026, 1, 1),
    )
    autopay_future_payment = session.exec(
        select(PaymentInstance).where(
            PaymentInstance.service_account_id == autopay_future.id
        )
    ).one()
    assert autopay_future_payment.status == PaymentStatus.autopay_future

    autopay = _service(
        session,
        initial_due_date=date(2026, 1, 10),
        is_autopay=True,
    )
    generate_payments_for_service(
        session,
        autopay,
        until_date=date(2026, 1, 10),
        today=date(2026, 1, 11),
    )
    autopay_payment = session.exec(
        select(PaymentInstance).where(PaymentInstance.service_account_id == autopay.id)
    ).one()
    assert autopay_payment.status == PaymentStatus.autopay_pending_confirmation


def test_weekend_adjustment_moves_due_dates(session: Session) -> None:
    saturday = date(2026, 1, 10)
    next_monday = _service(
        session,
        initial_due_date=saturday,
        weekend_adjustment=WeekendAdjustment.next_monday,
    )
    previous_friday = _service(
        session,
        initial_due_date=saturday,
        weekend_adjustment=WeekendAdjustment.previous_friday,
    )
    unchanged = _service(
        session,
        initial_due_date=saturday,
        weekend_adjustment=WeekendAdjustment.none,
    )

    generate_payments_for_service(session, next_monday, until_date=date(2026, 1, 31), today=date(2026, 1, 1))
    generate_payments_for_service(session, previous_friday, until_date=date(2026, 1, 31), today=date(2026, 1, 1))
    generate_payments_for_service(session, unchanged, until_date=date(2026, 1, 31), today=date(2026, 1, 1))

    due_dates = {
        payment.service_account_id: payment.due_date
        for payment in session.exec(select(PaymentInstance)).all()
    }
    assert due_dates[next_monday.id] == date(2026, 1, 12)
    assert due_dates[previous_friday.id] == date(2026, 1, 9)
    assert due_dates[unchanged.id] == saturday


def test_one_time_payment_and_mark_paid(session: Session) -> None:
    payment = create_one_time_payment(
        session,
        user_id=USER_ID,
        object_name="Oficina",
        service_name="Licencia SaaS",
        provider_name="Proveedor SaaS",
        service_number="INV-1",
        due_date=date(2026, 4, 10),
        estimated_amount=Decimal("250.00"),
    )
    mark_payment_paid(session, payment, paid_amount=Decimal("250.00"), paid_at=date(2026, 4, 9))

    assert payment.payment_type == PaymentType.one_time
    assert payment.status == PaymentStatus.paid
    assert payment.paid_at == date(2026, 4, 9)
    assert payment.paid_amount == Decimal("250.00")


def test_unmark_paid_restores_open_status(session: Session) -> None:
    payment = create_one_time_payment(
        session,
        user_id=USER_ID,
        object_name="Casa",
        service_name="Extra",
        provider_name="Proveedor",
        due_date=date.today(),
        estimated_amount=Decimal("50.00"),
    )
    mark_payment_paid(session, payment, paid_amount=Decimal("50.00"), paid_at=date.today())
    unmark_payment_paid(session, payment)

    assert payment.status != PaymentStatus.paid
    assert payment.paid_at is None
    assert payment.paid_amount is None


def test_patch_payment_marks_server_modified_for_sync(session: Session) -> None:
    payment = create_one_time_payment(
        session,
        user_id=USER_ID,
        object_name="Casa",
        service_name="Extra",
        provider_name="Proveedor",
        due_date=date.today(),
        estimated_amount=Decimal("50.00"),
    )
    previous_modified_at = datetime(2026, 1, 1)
    payment.last_modified_at = previous_modified_at
    payment.last_modified_platform = "android"
    payment.last_modified_device_id = "device-android"
    session.add(payment)
    session.commit()

    updated = update_payment(
        payment.id,
        PaymentUpdate(notes="Editado en web"),
        session=session,
        user_id=USER_ID,
    )

    assert updated.notes == "Editado en web"
    assert updated.last_modified_at > previous_modified_at
    assert updated.last_modified_platform == "server"
    assert updated.last_modified_device_id is None


def test_cancelled_payments_are_hidden_from_search_and_calendar(session: Session) -> None:
    payment = create_one_time_payment(
        session,
        user_id=USER_ID,
        object_name="Casa",
        service_name="Cancelado",
        provider_name="Proveedor",
        due_date=date(2026, 6, 10),
        estimated_amount=Decimal("75.00"),
    )
    cancel_payment(session, payment, reason="Prueba")
    session.commit()

    visible = list_payments(
        status_filter=None,
        session=session,
        user_id=USER_ID,
        limit=90,
        offset=0,
    )
    cancelled = list_payments(
        status_filter=PaymentStatus.cancelled,
        session=session,
        user_id=USER_ID,
        limit=90,
        offset=0,
    )
    cancelled_explicit = list_payments(
        status_filter=PaymentStatus.cancelled,
        include_cancelled=True,
        session=session,
        user_id=USER_ID,
        limit=90,
        offset=0,
    )
    calendar = get_calendar(
        start_date=date(2026, 6, 1),
        end_date=date(2026, 6, 30),
        session=session,
        user_id=USER_ID,
    )
    report = estimated_summary(
        start_date=date(2026, 6, 1),
        end_date=date(2026, 6, 30),
        include_cancelled=True,
        session=session,
        user_id=USER_ID,
    )

    assert visible == []
    assert cancelled == []
    assert [item.id for item in cancelled_explicit] == [payment.id]
    assert calendar.days == []
    assert report.payment_count == 1


def test_recalculation_cancels_future_without_touching_paid(session: Session) -> None:
    service = _service(session)
    generate_payments_for_service(
        session,
        service,
        until_date=date(2026, 6, 30),
        today=date(2026, 1, 1),
    )
    january = _payments(session)[0]
    mark_payment_paid(session, january, paid_amount=Decimal("100.00"), paid_at=date(2026, 1, 10))

    update_service_and_recalculate(
        session,
        service,
        {"estimated_amount": Decimal("125.00")},
        effective_from=date(2026, 3, 1),
        change_reason="Ajuste de tarifa",
        until_date=date(2026, 6, 30),
        today=date(2026, 1, 1),
    )

    all_payments = _payments(session)
    assert january.status == PaymentStatus.paid
    cancelled = [
        payment
        for payment in all_payments
        if payment.due_date >= date(2026, 3, 1)
        and payment.status == PaymentStatus.cancelled_by_recalculation
    ]
    replacements = [
        payment
        for payment in all_payments
        if payment.due_date >= date(2026, 3, 1)
        and payment.status == PaymentStatus.future
    ]
    assert len(cancelled) == 4
    assert len(replacements) == 4
    assert {payment.estimated_amount for payment in replacements} == {Decimal("125.00")}


def test_ending_service_cancels_recalculable_payments_without_replacements(session: Session) -> None:
    service = _service(session)
    generate_payments_for_service(
        session,
        service,
        until_date=date(2026, 5, 31),
        today=date(2026, 1, 1),
    )
    january = _payments(session)[0]
    mark_payment_paid(session, january, paid_amount=Decimal("100.00"), paid_at=date(2026, 1, 10))

    update_service_and_recalculate(
        session,
        service,
        {
            "status": ServiceLifecycleStatus.ended,
            "active": False,
            "ended_at": date(2026, 3, 1),
            "end_reason": "Servicio cancelado",
        },
        effective_from=date(2026, 3, 1),
        change_reason="Termino de suscripcion",
        until_date=date(2026, 5, 31),
        today=date(2026, 1, 1),
    )

    all_payments = _payments(session)
    assert service.status == ServiceLifecycleStatus.ended
    assert january.status == PaymentStatus.paid
    assert [
        payment.status
        for payment in all_payments
        if payment.due_date >= date(2026, 3, 1)
    ] == [
        PaymentStatus.cancelled_by_recalculation,
        PaymentStatus.cancelled_by_recalculation,
        PaymentStatus.cancelled_by_recalculation,
    ]


def test_paid_and_estimated_summaries(session: Session) -> None:
    service = _service(session)
    generate_payments_for_service(
        session,
        service,
        until_date=date(2026, 3, 31),
        today=date(2026, 1, 1),
    )
    january, february, _march = _payments(session)
    mark_payment_paid(session, january, paid_amount=Decimal("100.00"), paid_at=date(2026, 1, 20))

    paid = paid_summary(
        start_date=date(2026, 1, 1),
        end_date=date(2026, 1, 31),
        service_account_id=service.id,
        session=session,
        user_id=USER_ID,
    )
    estimated = estimated_summary(
        start_date=date(2026, 2, 1),
        end_date=date(2026, 2, 28),
        service_account_id=service.id,
        session=session,
        user_id=USER_ID,
    )

    assert paid.payment_count == 1
    assert paid.total_amount == Decimal("100.00")
    assert estimated.payment_count == 1
    assert estimated.total_amount == february.estimated_amount
