from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import Column, String
from sqlmodel import Field, SQLModel

from app.models.base import utc_now


class UserEntitlement(SQLModel, table=True):
    __tablename__ = "user_entitlements"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="users.id", index=True, nullable=False)
    plan: str = Field(sa_column=Column(String(32), nullable=False, index=True))
    status: str = Field(sa_column=Column(String(32), nullable=False, index=True))
    source: str = Field(sa_column=Column(String(64), nullable=False, default="manual"))
    current_period_end: date | None = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
    updated_at: datetime = Field(default_factory=utc_now, nullable=False)
