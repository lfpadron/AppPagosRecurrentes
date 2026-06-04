from functools import cached_property
from uuid import UUID

from pydantic import computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Pagos Recurrentes API"
    environment: str = "local"
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/recurrent_payments"
    default_user_id: UUID = UUID("00000000-0000-0000-0000-000000000001")
    generation_horizon_months: int = 36
    due_soon_days: int = 7
    upcoming_days: int = 14
    backend_cors_origins: str = "http://localhost:3000,http://localhost:5173,http://localhost:8080,http://localhost:8081"
    db_echo: bool = False

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @computed_field
    @cached_property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.backend_cors_origins.split(",") if origin.strip()]


settings = Settings()
