from collections.abc import Generator
from uuid import UUID

import pytest
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

import app.models  # noqa: F401
from app.models.user import User


@pytest.fixture
def session() -> Generator[Session, None, None]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        user = User(
            id=UUID("00000000-0000-0000-0000-000000000001"),
            email="test@example.com",
            name="Test User",
        )
        session.add(user)
        session.commit()
        yield session
    SQLModel.metadata.drop_all(engine)
