from datetime import datetime

from sqlalchemy import Column, String
from sqlmodel import Field, SQLModel

from app.models.base import utc_now


class AppSchemaVersion(SQLModel, table=True):
    __tablename__ = "app_schema_versions"

    id: str = Field(default="main", sa_column=Column(String(32), primary_key=True))
    version: int = Field(nullable=False)
    description: str | None = Field(default=None, sa_column=Column(String(200), nullable=True))
    applied_at: datetime = Field(default_factory=utc_now, nullable=False)
