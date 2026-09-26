"""Authentication & authorization helpers.

Two trust boundaries are enforced here:

1.  Every protected route MUST depend on :func:`require_authenticated_user`
    which validates the incoming `Authorization: Bearer <jwt>` header
    against the Supabase admin GoTrue endpoint. The JWT itself is
    opaque to this backend — we do not need to inspect its claims; the
    user id (the `sub` claim) is what we propagate everywhere.

2.  Every user-owned Supabase row access is enforced server-side via
    the user's JWT passed to PostgREST. We never use the service-role
    client to read user-owned tables; that would bypass row-level
    security and is the single most common cause of cross-user leaks.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

import httpx
from fastapi import Depends, Header, HTTPException, status

from .config import Settings, get_settings

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class AuthenticatedUser:
    """The authenticated identity for the current request."""

    id: str
    email: Optional[str] = None
    raw_token: str = ""  # Only used to forward to Supabase as the user JWT.


def _bearer_token(authorization: Optional[str]) -> str:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "UNAUTHENTICATED", "message": "Missing Authorization header."},
            headers={"WWW-Authenticate": "Bearer"},
        )
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "UNAUTHENTICATED", "message": "Malformed Authorization header."},
            headers={"WWW-Authenticate": "Bearer"},
        )
    return parts[1].strip()


async def _verify_with_supabase(settings: Settings, token: str) -> AuthenticatedUser:
    """Validate the JWT with Supabase and return the canonical user."""
    if not settings.supabase_url:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AUTH_BACKEND_UNCONFIGURED", "message": "Auth backend not configured."},
        )
    url = settings.supabase_url.rstrip("/") + "/auth/v1/user"
    headers = {
        "Authorization": f"Bearer {token}",
        "apikey": settings.supabase_service_role_key,
    }
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url, headers=headers)
    except httpx.RequestError as e:
        log.warning("supabase_auth_unreachable", extra={"err": str(e)})
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AUTH_BACKEND_UNAVAILABLE", "message": "Auth backend unreachable."},
        )
    if resp.status_code == 401:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN", "message": "Token rejected by auth provider."},
            headers={"WWW-Authenticate": "Bearer"},
        )
    if resp.status_code >= 400:
        log.warning("supabase_auth_error", extra={"status": resp.status_code})
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AUTH_BACKEND_ERROR", "message": "Auth provider returned an error."},
        )
    payload = resp.json()
    user_id = payload.get("id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN", "message": "Token did not resolve to a user."},
            headers={"WWW-Authenticate": "Bearer"},
        )
    email = payload.get("email")
    return AuthenticatedUser(id=user_id, email=email, raw_token=token)


async def require_authenticated_user(
    authorization: Optional[str] = Header(default=None),
) -> AuthenticatedUser:
    """FastAPI dependency — every protected route declares it."""
    settings = get_settings()
    token = _bearer_token(authorization)
    return await _verify_with_supabase(settings, token)


__all__ = ["AuthenticatedUser", "require_authenticated_user"]
