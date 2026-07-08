from uuid import UUID

from fastapi import APIRouter, Depends
from fastapi.encoders import jsonable_encoder
from sqlalchemy import func
from sqlmodel import Session, select

from app.api.deps import get_current_user, get_current_user_id
from app.db.session import get_session
from app.models.base import utc_now
from app.models.payment_instance import PaymentInstance
from app.models.service_account import ServiceAccount
from app.models.sync_device import SyncDevice
from app.models.user import User
from app.schemas.payments import PaymentInstanceRead
from app.schemas.services import ServiceAccountRead
from app.schemas.sync import (
    SyncBootstrapRequest,
    SyncBootstrapResponse,
    SyncPullResponse,
    SyncStatusResponse,
)
from app.services.sync import bootstrap_from_device
from app.services.users import is_user_premium

router = APIRouter(prefix="/sync", tags=["sync"])


@router.get("/status", response_model=SyncStatusResponse)
def sync_status(
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> SyncStatusResponse:
    return SyncStatusResponse(
        user_id=user.id,
        is_premium=is_user_premium(session, user),
        server_time=utc_now(),
        service_count=_count(session, ServiceAccount, user.id),
        payment_count=_count(session, PaymentInstance, user.id),
        device_count=_count(session, SyncDevice, user.id),
    )


@router.post("/bootstrap", response_model=SyncBootstrapResponse)
def sync_bootstrap(
    payload: SyncBootstrapRequest,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> SyncBootstrapResponse:
    return bootstrap_from_device(session, user_id=user_id, payload=payload)


@router.get("/pull", response_model=SyncPullResponse)
def sync_pull(
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> SyncPullResponse:
    services = session.exec(
        select(ServiceAccount)
        .where(ServiceAccount.user_id == user_id)
        .order_by(ServiceAccount.object_name, ServiceAccount.service_name)
    ).all()
    payments = session.exec(
        select(PaymentInstance)
        .where(PaymentInstance.user_id == user_id)
        .order_by(PaymentInstance.due_date, PaymentInstance.created_at)
    ).all()
    return SyncPullResponse(
        services=jsonable_encoder([ServiceAccountRead.model_validate(item) for item in services]),
        payments=jsonable_encoder([PaymentInstanceRead.model_validate(item) for item in payments]),
    )


def _count(session: Session, model, user_id: UUID) -> int:
    statement = select(func.count()).select_from(model).where(model.user_id == user_id)
    return session.exec(statement).one()
