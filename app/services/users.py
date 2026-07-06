from datetime import date
from uuid import UUID

from sqlmodel import Session, select

from app.core.config import settings
from app.models.base import utc_now
from app.models.user import User
from app.models.user_entitlement import UserEntitlement


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


def ensure_user_from_auth(
    session: Session,
    user_id: UUID,
    *,
    email: str,
    name: str | None = None,
) -> User:
    existing = session.get(User, user_id)
    normalized_email = email.strip().lower()
    display_name = (name or normalized_email.split("@")[0] or "Usuario").strip()
    now = utc_now()

    if existing:
        changed = False
        if existing.email != normalized_email:
            existing.email = normalized_email
            changed = True
        if display_name and existing.name != display_name:
            existing.name = display_name
            changed = True
        if changed:
            existing.updated_at = now
            session.add(existing)
            session.commit()
            session.refresh(existing)
        return existing

    user = User(
        id=user_id,
        email=normalized_email,
        name=display_name,
        created_at=now,
        updated_at=now,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def is_user_premium(session: Session, user: User) -> bool:
    if user.email.lower() in settings.premium_emails:
        return True

    today = date.today()
    statement = (
        select(UserEntitlement)
        .where(UserEntitlement.user_id == user.id)
        .where(UserEntitlement.plan == "premium")
        .where(UserEntitlement.status == "active")
    )
    entitlements = session.exec(statement).all()
    return any(
        entitlement.current_period_end is None
        or entitlement.current_period_end >= today
        for entitlement in entitlements
    )
