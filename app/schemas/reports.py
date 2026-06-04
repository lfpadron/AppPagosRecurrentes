from datetime import date
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel


class ReportSummary(BaseModel):
    start_date: date
    end_date: date
    service_account_id: UUID | None = None
    payment_count: int
    total_amount: Decimal
    currency: str = "MXN"
    totals_by_status: dict[str, Decimal]
