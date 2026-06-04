from uuid import UUID

from sqlmodel import Session

from app.models.base import utc_now
from app.models.user import User


def ensure_user(session: Session, user_id: UUID) -> User:
    existing = session.get(User, user_id)
    if existing:
        return existing

    user = User(
        id=user_id,
        email=f"{user_id}@local.test",
        name="Usuario local",
        created_at=utc_now(),
        updated_at=utc_now(),
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user
