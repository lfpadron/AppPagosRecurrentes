from uuid import UUID

from fastapi import Depends, Header
from sqlmodel import Session

from app.core.config import settings
from app.db.session import get_session
from app.services.users import ensure_user


def get_current_user_id(
    session: Session = Depends(get_session),
    x_user_id: UUID | None = Header(default=None, alias="X-User-Id"),
) -> UUID:
    user_id = x_user_id or settings.default_user_id
    ensure_user(session, user_id)
    return user_id
