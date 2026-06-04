from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Column, Integer, String
from sqlmodel import Field, SQLModel

from app.models.base import utc_now


class Attachment(SQLModel, table=True):
    __tablename__ = "attachments"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="users.id", index=True, nullable=False)
    payment_instance_id: UUID = Field(foreign_key="payment_instances.id", index=True, nullable=False)
    file_name: str = Field(sa_column=Column(String(255), nullable=False))
    file_url: str = Field(sa_column=Column(String(1000), nullable=False))
    mime_type: str = Field(sa_column=Column(String(120), nullable=False))
    size_bytes: int = Field(sa_column=Column(Integer, nullable=False))
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
