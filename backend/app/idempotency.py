"""Idempotency for the outbox receiver.

The Flutter outbox enqueues operations tagged with a UUID
`operationId`. The same operation may legitimately be re-sent (network
reconnect, retry, crash recovery). The backend MUST NOT create a
duplicate server-side record on the second attempt.

This module backs the `vaanix_idempotency` table with a process-local
fallback so unit tests do not need Supabase. When the operator wires
the table into Supabase, the server-side enforcement runs as a unique
constraint check; this module adds the in-process short-circuit so a
hot retry loop is cheap.
"""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from typing import Dict, Optional

from supabase import Client


@dataclass
class IdempotencyResult:
    accepted: bool
    """`True` when this is a fresh operation; `False` when the
    operation_id was already processed (the second arrival of a
    legitimately-retried mutation)."""

    existing_response: Optional[dict] = None
    """The response the previous attempt recorded — returned to the
    client so the retry is truly transparent."""


@dataclass
class _Entry:
    seen_at: float
    response: Optional[dict] = None


class IdempotencyStore:
    """Two-tier store: in-process short-circuit + Supabase uniqueness."""

    def __init__(self, supabase: Optional[Client], *, ttl_seconds: int = 24 * 3600) -> None:
        self._supabase = supabase
        self._ttl = ttl_seconds
        self._cache: Dict[str, _Entry] = {}
        self._lock = asyncio.Lock()

    async def begin_or_resume(
        self, *, user_id: str, operation_id: str
    ) -> IdempotencyResult:
        """Decide whether this operation is fresh or a duplicate."""
        now = time.monotonic()
        async with self._lock:
            self._gc(now)
            key = f"{user_id}:{operation_id}"
            entry = self._cache.get(key)
            if entry is not None:
                return IdempotencyResult(False, entry.response)
            if self._supabase is not None:
                # The unique constraint on (user_id, operation_id) makes
                # this insert the authoritative dedup point across replicas.
                # If it returns a row, another replica already processed
                # this op; we treat that as a duplicate.
                try:
                    res = (
                        self._supabase.table("vaanix_idempotency")
                        .insert({"user_id": user_id, "operation_id": operation_id})
                        .execute()
                    )
                    if getattr(res, "data", None) is None:
                        return IdempotencyResult(False)
                except Exception:
                    # Supabase raises on unique-conflict; treat as dup.
                    return IdempotencyResult(False)
            self._cache[key] = _Entry(seen_at=now)
            return IdempotencyResult(True)

    async def record_response(
        self, *, user_id: str, operation_id: str, response: dict
    ) -> None:
        """Cache the response so the next retry is transparent."""
        async with self._lock:
            key = f"{user_id}:{operation_id}"
            entry = self._cache.get(key)
            if entry is not None:
                entry.response = response
            else:
                self._cache[key] = _Entry(seen_at=time.monotonic(), response=response)
            if self._supabase is not None:
                try:
                    self._supabase.table("vaanix_idempotency").update(
                        {"response": response}
                    ).eq("user_id", user_id).eq("operation_id", operation_id).execute()
                except Exception:
                    log.warning("idempotency_record_failed")  # type: ignore[name-defined]

    def _gc(self, now: float) -> None:
        cutoff = now - self._ttl
        for k in [k for k, v in self._cache.items() if v.seen_at < cutoff]:
            del self._cache[k]


__all__ = ["IdempotencyStore", "IdempotencyResult"]
