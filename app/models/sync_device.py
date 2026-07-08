from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Column, String
from sqlmodel import Field, SQLModel

from app.models.base import utc_now


class SyncDevice(SQLModel, table=True):
    __tablename__ = "sync_devices"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="users.id", index=True, nullable=False)
    device_id: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    platform: str = Field(default="unknown", sa_column=Column(String(32), nullable=False))
    app_schema_version: int | None = Field(default=None, nullable=True)
    last_seen_at: datetime = Field(default_factory=utc_now, nullable=False)
    last_bootstrap_at: datetime | None = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
    updated_at: datetime = Field(default_factory=utc_now, nullable=False)
