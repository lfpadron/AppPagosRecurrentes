import calendar
from datetime import date, timedelta

from app.models.enums import Frequency
from app.models.enums import WeekendAdjustment


def add_months(value: date, months: int) -> date:
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    last_day = calendar.monthrange(year, month)[1]
    return value.replace(year=year, month=month, day=min(value.day, last_day))


def occurrence_date(initial: date, frequency: Frequency, interval_count: int, occurrence_index: int) -> date:
    if frequency == Frequency.weekly:
        return initial + timedelta(weeks=interval_count * occurrence_index)
    if frequency == Frequency.biweekly:
        return initial + timedelta(weeks=2 * interval_count * occurrence_index)
    if frequency == Frequency.monthly:
        return add_months(initial, interval_count * occurrence_index)
    if frequency == Frequency.yearly:
        return add_months(initial, 12 * interval_count * occurrence_index)
    raise ValueError(f"Unsupported frequency: {frequency}")


def adjust_weekend(value: date, policy: WeekendAdjustment) -> date:
    if policy == WeekendAdjustment.next_monday:
        if value.weekday() == 5:
            return value + timedelta(days=2)
        if value.weekday() == 6:
            return value + timedelta(days=1)
    if policy == WeekendAdjustment.previous_friday:
        if value.weekday() == 5:
            return value - timedelta(days=1)
        if value.weekday() == 6:
            return value - timedelta(days=2)
    return value
