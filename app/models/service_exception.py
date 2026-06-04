from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import Column, Text
from sqlmodel import Field, SQLModel

from app.models.base import utc_now


class ServiceException(SQLModel, table=True):
    __tablename__ = "service_exceptions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    service_account_id: UUID = Field(foreign_key="service_accounts.id", index=True, nullable=False)
    start_date: date = Field(nullable=False, index=True)
    end_date: date = Field(nullable=False, index=True)
    reason: str | None = Field(default=None, sa_column=Column(Text, nullable=True))
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
