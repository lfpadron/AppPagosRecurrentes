from enum import Enum


class Frequency(str, Enum):
    weekly = "weekly"
    biweekly = "biweekly"
    monthly = "monthly"
    yearly = "yearly"


class ServiceLifecycleStatus(str, Enum):
    active = "active"
    paused = "paused"
    ended = "ended"


class WeekendAdjustment(str, Enum):
    none = "none"
    next_monday = "next_monday"
    previous_friday = "previous_friday"


class PaymentType(str, Enum):
    recurring = "recurring"
    one_time = "one_time"


class PaymentStatus(str, Enum):
    future = "future"
    upcoming = "upcoming"
    due_soon = "due_soon"
    pending = "pending"
    active = "active"
    autopay_due_soon = "autopay_due_soon"
    autopay_future = "autopay_future"
    autopay_pending_confirmation = "autopay_pending_confirmation"
    overdue = "overdue"
    autopay_overdue_confirmation = "autopay_overdue_confirmation"
    paid = "paid"
    not_applicable_exception = "not_applicable_exception"
    cancelled = "cancelled"
    cancelled_by_recalculation = "cancelled_by_recalculation"


RECALCULABLE_STATUSES = {
    PaymentStatus.future,
    PaymentStatus.upcoming,
    PaymentStatus.due_soon,
    PaymentStatus.pending,
    PaymentStatus.autopay_due_soon,
    PaymentStatus.autopay_future,
    PaymentStatus.autopay_pending_confirmation,
}

OPEN_PAYMENT_STATUSES = {
    PaymentStatus.future,
    PaymentStatus.upcoming,
    PaymentStatus.due_soon,
    PaymentStatus.pending,
    PaymentStatus.active,
    PaymentStatus.overdue,
    PaymentStatus.autopay_due_soon,
    PaymentStatus.autopay_future,
    PaymentStatus.autopay_pending_confirmation,
    PaymentStatus.autopay_overdue_confirmation,
}

TERMINAL_STATUSES = {
    PaymentStatus.paid,
    PaymentStatus.not_applicable_exception,
    PaymentStatus.cancelled,
    PaymentStatus.cancelled_by_recalculation,
}
