from datetime import date
from uuid import UUID

from pydantic import BaseModel


class AuthMeResponse(BaseModel):
    id: UUID
    email: str
    name: str
    is_premium: bool
    plan: str
    premium_source: str | None = None
    current_period_end: date | None = None
