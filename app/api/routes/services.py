from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select

from app.api.deps import get_current_user_id
from app.db.session import get_session
from app.models.base import utc_now
from app.models.enums import ServiceLifecycleStatus
from app.models.service_account import ServiceAccount
from app.models.service_exception import ServiceException
from app.models.service_version import ServiceVersion
from app.schemas.payments import PaymentInstanceRead
from app.schemas.services import (
    RegeneratePaymentsRequest,
    ServiceAccountCreate,
    ServiceAccountRead,
    ServiceAccountUpdate,
    ServiceExceptionCreate,
    ServiceExceptionRead,
    ServiceVersionRead,
)
from app.services.payment_generation import (
    apply_exception_to_existing_payments,
    cancel_recalculable_payments,
    generate_payments_for_service,
)
from app.services.service_accounts import update_service_and_recalculate

router = APIRouter(prefix="/services", tags=["services"])


def _normalize_lifecycle(data: dict, effective_from: date) -> dict:
    status_value = data.get("status")
    if status_value is None:
        return data

    status_normalized = (
        status_value
        if isinstance(status_value, ServiceLifecycleStatus)
        else ServiceLifecycleStatus(status_value)
    )
    data["active"] = status_normalized == ServiceLifecycleStatus.active

    if status_normalized == ServiceLifecycleStatus.paused:
        data.setdefault("paused_from", effective_from)
    elif status_normalized == ServiceLifecycleStatus.ended:
        data.setdefault("ended_at", effective_from)
        data["paused_from"] = None
    elif status_normalized == ServiceLifecycleStatus.active:
        data["paused_from"] = None
        data["ended_at"] = None
        data["end_reason"] = None

    return data


def _get_service_or_404(session: Session, service_id: UUID, user_id: UUID) -> ServiceAccount:
    service = session.get(ServiceAccount, service_id)
    if not service or service.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    return service


@router.post("", response_model=ServiceAccountRead, status_code=status.HTTP_201_CREATED)
def create_service(
    payload: ServiceAccountCreate,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> ServiceAccount:
    data = _normalize_lifecycle(payload.model_dump(), date.today())
    service = ServiceAccount(user_id=user_id, **data)
    now = utc_now()
    service.updated_at = now
    service.last_modified_at = now
    service.last_modified_platform = "server"
    session.add(service)
    session.flush()
    generate_payments_for_service(session, service)
    session.commit()
    session.refresh(service)
    return service


@router.get("", response_model=list[ServiceAccountRead])
def list_services(
    object_name: str | None = None,
    status_filter: ServiceLifecycleStatus | None = Query(default=None, alias="status"),
    limit: int = Query(default=30, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> list[ServiceAccount]:
    statement = select(ServiceAccount).where(ServiceAccount.user_id == user_id)
    if object_name:
        statement = statement.where(ServiceAccount.object_name.ilike(f"%{object_name}%"))
    if status_filter:
        statement = statement.where(ServiceAccount.status == status_filter)
    statement = (
        statement.order_by(ServiceAccount.object_name, ServiceAccount.service_name)
        .offset(offset)
        .limit(limit)
    )
    return session.exec(statement).all()


@router.get("/{service_id}", response_model=ServiceAccountRead)
def get_service(
    service_id: UUID,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> ServiceAccount:
    return _get_service_or_404(session, service_id, user_id)


@router.patch("/{service_id}", response_model=ServiceAccountRead)
def update_service(
    service_id: UUID,
    payload: ServiceAccountUpdate,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> ServiceAccount:
    service = _get_service_or_404(session, service_id, user_id)
    effective_from = payload.effective_from or date.today()
    data = payload.model_dump(exclude_unset=True, exclude={"effective_from", "change_reason"})
    data = _normalize_lifecycle(data, effective_from)
    if not data:
        return service

    update_service_and_recalculate(
        session,
        service,
        data,
        effective_from=effective_from,
        change_reason=payload.change_reason,
    )
    session.commit()
    session.refresh(service)
    return service


@router.post("/{service_id}/regenerate-payments", response_model=list[PaymentInstanceRead])
def regenerate_payments(
    service_id: UUID,
    payload: RegeneratePaymentsRequest | None = None,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
):
    service = _get_service_or_404(session, service_id, user_id)
    start_date = payload.start_date if payload else date.today()
    horizon_months = payload.horizon_months if payload else None
    cancel_recalculable_payments(session, service.id, start_date)
    created = generate_payments_for_service(
        session,
        service,
        start_date=start_date,
        horizon_months=horizon_months,
    )
    session.commit()
    for payment in created:
        session.refresh(payment)
    return created


@router.post("/{service_id}/exceptions", response_model=ServiceExceptionRead, status_code=status.HTTP_201_CREATED)
def create_exception(
    service_id: UUID,
    payload: ServiceExceptionCreate,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> ServiceException:
    _get_service_or_404(session, service_id, user_id)
    exception = ServiceException(service_account_id=service_id, **payload.model_dump())
    session.add(exception)
    apply_exception_to_existing_payments(session, service_id, payload.start_date, payload.end_date)
    session.commit()
    session.refresh(exception)
    return exception


@router.get("/{service_id}/versions", response_model=list[ServiceVersionRead])
def list_versions(
    service_id: UUID,
    session: Session = Depends(get_session),
    user_id: UUID = Depends(get_current_user_id),
) -> list[ServiceVersion]:
    _get_service_or_404(session, service_id, user_id)
    statement = (
        select(ServiceVersion)
        .where(ServiceVersion.service_account_id == service_id)
        .order_by(ServiceVersion.created_at.desc())
    )
    return session.exec(statement).all()
