from datetime import date, timedelta
from uuid import UUID

from sqlmodel import Session

from app.models.user import User
from app.models.user_entitlement import UserEntitlement
from app.services.users import is_user_premium


USER_ID = UUID("00000000-0000-0000-0000-000000000001")


def test_active_premium_entitlement_grants_premium(session: Session) -> None:
    user = session.get(User, USER_ID)
    assert user is not None
    session.add(
        UserEntitlement(
            user_id=USER_ID,
            plan="premium",
            status="active",
            source="test",
            current_period_end=date.today() + timedelta(days=30),
        )
    )
    session.commit()

    assert is_user_premium(session, user)


def test_expired_premium_entitlement_does_not_grant_premium(session: Session) -> None:
    user = session.get(User, USER_ID)
    assert user is not None
    session.add(
        UserEntitlement(
            user_id=USER_ID,
            plan="premium",
            status="active",
            source="test",
            current_period_end=date.today() - timedelta(days=1),
        )
    )
    session.commit()

    assert not is_user_premium(session, user)
