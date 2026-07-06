from uuid import UUID

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel import Session

from app.core.config import settings
from app.db.session import get_session
from app.models.user import User
from app.services.auth import verify_supabase_token
from app.services.users import ensure_user, ensure_user_from_auth, is_user_premium


bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    session: Session = Depends(get_session),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    x_user_id: UUID | None = Header(default=None, alias="X-User-Id"),
) -> User:
    if settings.auth_provider.lower() == "supabase":
        if not credentials:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Autenticacion requerida.",
            )
        auth_user = verify_supabase_token(credentials.credentials)
        return ensure_user_from_auth(
            session,
            auth_user.id,
            email=auth_user.email,
            name=auth_user.name,
        )

    user_id = x_user_id or settings.default_user_id
    return ensure_user(session, user_id)


def get_current_user_id(
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> UUID:
    if settings.require_premium_for_api and not is_user_premium(session, user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere plan Premium activo.",
        )
    return user.id
