from datetime import date

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.models.user_entitlement import UserEntitlement
from app.schemas.auth import AuthMeResponse
from app.services.users import is_user_premium
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/me", response_model=AuthMeResponse)
def get_me(
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> AuthMeResponse:
    premium = is_user_premium(session, user)
    entitlement = _current_premium_entitlement(session, user)
    source = entitlement.source if entitlement else None
    period_end = entitlement.current_period_end if entitlement else None

    if premium and user.email.lower() in settings.premium_emails and not source:
        source = "allowlist"

    return AuthMeResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        is_premium=premium,
        plan="premium" if premium else "economic",
        premium_source=source,
        current_period_end=period_end,
    )


def _current_premium_entitlement(
    session: Session,
    user: User,
) -> UserEntitlement | None:
    today = date.today()
    statement = (
        select(UserEntitlement)
        .where(UserEntitlement.user_id == user.id)
        .where(UserEntitlement.plan == "premium")
        .where(UserEntitlement.status == "active")
    )
    for entitlement in session.exec(statement).all():
        if (
            entitlement.current_period_end is None
            or entitlement.current_period_end >= today
        ):
            return entitlement
    return None
