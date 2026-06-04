from datetime import date
from decimal import Decimal

from sqlmodel import Session, select

from app.core.config import settings
from app.db.session import engine
from app.models.enums import Frequency
from app.models.payment_instance import PaymentInstance
from app.models.service_account import ServiceAccount
from app.services.payment_generation import generate_payments_for_service
from app.services.users import ensure_user


def run() -> None:
    with Session(engine) as session:
        user = ensure_user(session, settings.default_user_id)
        user.email = "demo@pagos.local"
        user.name = "Usuario demo"
        session.add(user)

        old_seed = session.exec(
            select(ServiceAccount)
            .where(ServiceAccount.user_id == user.id)
            .where(ServiceAccount.service_number == "CFE-DEMO-001")
        ).first()
        if old_seed:
            old_payments = session.exec(
                select(PaymentInstance).where(
                    PaymentInstance.service_account_id == old_seed.id
                )
            ).all()
            for payment in old_payments:
                session.delete(payment)
            session.delete(old_seed)

        existing = session.exec(
            select(ServiceAccount)
            .where(ServiceAccount.user_id == user.id)
            .where(ServiceAccount.service_number == "DEMO-EJEMPLO-001")
        ).first()
        if existing:
            session.commit()
            return

        service = ServiceAccount(
            user_id=user.id,
            object_name="Casa",
            service_name="Ejemplo",
            provider_name="proveedor",
            service_number="DEMO-EJEMPLO-001",
            icon_key="service_default",
            initial_due_date=date(2026, 1, 30),
            frequency=Frequency.monthly,
            interval_count=1,
            estimated_amount=Decimal("900.00"),
            notes="Servicio seed para validar el flujo completo.",
        )
        session.add(service)
        session.flush()
        generate_payments_for_service(session, service)
        session.commit()


if __name__ == "__main__":
    run()
