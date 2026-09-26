"""User-data endpoints.

Exposes the minimal profile surface Flutter needs to render after
sign-in. Profile updates flow through the outbox (`upsert_learn_profile`)
so they ride the same idempotent, retryable path as everything else.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status

from .config import get_settings
from .models import UserProfile
from .security import AuthenticatedUser, require_authenticated_user

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/users", tags=["users"])


@router.get("/me", response_model=UserProfile, summary="Current user profile")
async def me(user: AuthenticatedUser = Depends(require_authenticated_user)) -> UserProfile:
    settings = get_settings()
    url = (
        settings.supabase_url.rstrip("/")
        + f"/rest/v1/users?id=eq.{user.id}&select=id,email,created_at,"
        + "display_name,preferred_language"
    )
    headers = {
        "Authorization": f"Bearer {user.raw_token}",
        "apikey": settings.supabase_service_role_key,
        "Accept": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url, headers=headers)
    except httpx.RequestError as e:
        log.warning("profile_unreachable", extra={"err": str(e)})
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "SUPABASE_UNAVAILABLE", "message": "Profile backend unreachable."},
        )
    if resp.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={"code": "PROFILE_LOOKUP_FAILED", "message": "Profile lookup failed."},
        )
    rows = resp.json() if resp.content else []
    if not rows:
        # Auth user exists in Supabase auth.users but no VaaniX profile
        # row yet. Return a synthesised profile so the Flutter client
        # can show the first-run UI without crashing.
        return UserProfile(
            id=user.id,
            email=user.email,
            created_at=datetime.now(timezone.utc),
        )
    row = rows[0]
    return UserProfile(
        id=row.get("id", user.id),
        email=row.get("email", user.email),
        created_at=row.get("created_at") or datetime.now(timezone.utc),
        display_name=row.get("display_name"),
        preferred_language=row.get("preferred_language"),
    )


__all__ = ["router"]
