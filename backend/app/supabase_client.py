"""Thin Supabase admin-client wrapper.

`SUPABASE_SERVICE_ROLE_KEY` is privileged. It MUST never leave the
backend. The wrapper below keeps the key inside one place and exposes
only typed accessors for the small set of operations the backend
needs (token verification, profile lookup, idempotency store).
"""

from __future__ import annotations

from functools import lru_cache
from typing import Any, Dict, Optional

from supabase import Client, create_client

from .config import Settings, get_settings


@lru_cache(maxsize=1)
def _admin_client(settings_id: int) -> Optional[Client]:
    """Cached admin client. The cache key uses `id(settings)` so the
    instance is re-built if the settings module reloads in tests."""
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_service_role_key:
        return None
    if settings.supabase_service_role_key.lower().startswith("ey..."):
        # Placeholder value present in `.env.example` — refuse to boot.
        return None
    return create_client(
        settings.supabase_url, settings.supabase_service_role_key
    )


def get_admin_client() -> Optional[Client]:
    """Return the cached Supabase admin client, or `None` when not configured."""
    return _admin_client(id(get_settings()))


def reset_admin_client_cache() -> None:
    """Test helper — drop the cached client."""
    _admin_client.cache_clear()


__all__ = ["get_admin_client", "reset_admin_client_cache"]
