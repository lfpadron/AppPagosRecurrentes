from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Column, String, UniqueConstraint
from sqlmodel import Field, SQLModel

from app.models.base import utc_now


class SyncExternalId(SQLModel, table=True):
    __tablename__ = "sync_external_ids"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "device_id",
            "entity_type",
            "local_id",
            name="uq_sync_external_ids_local",
        ),
    )

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="users.id", index=True, nullable=False)
    device_id: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    entity_type: str = Field(sa_column=Column(String(32), nullable=False, index=True))
    local_id: str = Field(sa_column=Column(String(160), nullable=False, index=True))
    server_id: UUID = Field(index=True, nullable=False)
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
