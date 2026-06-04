from collections.abc import Generator

from sqlmodel import Session, create_engine

from app.core.config import settings


def _connect_args() -> dict[str, bool]:
    if settings.database_url.startswith("sqlite"):
        return {"check_same_thread": False}
    return {}


engine = create_engine(settings.database_url, echo=settings.db_echo, connect_args=_connect_args())


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
