from dataclasses import dataclass
from uuid import UUID

import httpx
from fastapi import HTTPException, status

from app.core.config import settings


@dataclass(frozen=True)
class AuthenticatedUser:
    id: UUID
    email: str
    name: str | None = None


def verify_supabase_token(token: str) -> AuthenticatedUser:
    if not settings.supabase_url or not settings.supabase_anon_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Supabase Auth no esta configurado en el backend.",
        )

    url = settings.supabase_url.rstrip("/") + "/auth/v1/user"
    headers = {
        "Authorization": f"Bearer {token}",
        "apikey": settings.supabase_anon_key,
    }
    try:
        response = httpx.get(url, headers=headers, timeout=8.0)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No fue posible validar la sesion de usuario.",
        ) from exc

    if response.status_code in {status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN}:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sesion invalida o expirada.",
        )
    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase Auth rechazo la validacion de sesion.",
        )

    payload = response.json()
    user_id = payload.get("id")
    email = payload.get("email")
    metadata = payload.get("user_metadata") or {}
    name = metadata.get("name") or metadata.get("full_name")

    if not user_id or not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="La sesion no contiene usuario valido.",
        )

    return AuthenticatedUser(id=UUID(user_id), email=email, name=name)
