"""Health endpoints.

`/health` is the liveness probe — must always respond and must not
require authentication. Used by load balancers, uptime monitors, and
the Flutter client to confirm the backend is reachable before any
real traffic is generated.

`/health/ready` is a deeper readiness probe — checks that the auth
backend (Supabase) is reachable.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, Depends

from .config import get_settings
from .security import require_authenticated_user, AuthenticatedUser

log = logging.getLogger(__name__)

router = APIRouter(tags=["health"])

SERVICE_NAME = "vaanix-backend"
SERVICE_VERSION = "0.1.0"


@router.get("/health", summary="Liveness probe")
async def liveness() -> dict:
    return {
        "status": "ok",
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "timestamp": datetime.now(timezone.utc),
    }


@router.get("/health/ready", summary="Readiness probe (auth check)")
async def readiness(
    user: AuthenticatedUser = Depends(require_authenticated_user),
) -> dict:
    """Readiness = the auth dependency accepted the bearer token.

    If we get here, the auth backend was reachable AND the token was
    valid. The Flutter client can treat a 200 as 'this backend is
    ready to serve authenticated traffic'; 401 means either the auth
    backend is down (the dependency itself raises 503) or the token
    is rejected.
    """
    return {
        "status": "ok",
        "service": SERVICE_NAME,
        "auth_user_id": user.id,
        "timestamp": datetime.now(timezone.utc),
    }


__all__ = ["router"]
