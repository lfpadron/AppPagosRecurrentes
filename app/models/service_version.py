from datetime import date, datetime
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import Column, JSON, Text
from sqlmodel import Field, SQLModel

from app.models.base import utc_now


class ServiceVersion(SQLModel, table=True):
    __tablename__ = "service_versions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    service_account_id: UUID = Field(foreign_key="service_accounts.id", index=True, nullable=False)
    version_number: int = Field(nullable=False, index=True)
    snapshot_json: dict[str, Any] = Field(sa_column=Column(JSON, nullable=False))
    change_reason: str | None = Field(default=None, sa_column=Column(Text, nullable=True))
    effective_from: date = Field(nullable=False, index=True)
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
