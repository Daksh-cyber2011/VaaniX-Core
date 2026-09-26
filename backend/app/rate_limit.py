"""In-process token-bucket rate limiter.

Two limits are enforced:

* A global per-IP limit (`RATE_LIMIT_PER_MINUTE`) on every route —
  cheap rejection of obvious abuse before any business logic runs.
* A per-user hourly limit on the AI proxy
  (`AI_RATE_LIMIT_PER_HOUR_PER_USER`) — protects against a single
  authenticated account burning the provider's quota.

The bucket state is process-local. For multi-replica deployments the
operator should front the service with a shared limiter (e.g. an
edge proxy) — but the in-process bucket is still useful because it
short-circuits requests without a network hop.
"""

from __future__ import annotations

import asyncio
import time
from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Deque, Dict

from fastapi import HTTPException, Request, status


@dataclass
class _Bucket:
    window_seconds: int
    hits: Deque[float]

    def consume(self, now: float) -> bool:
        # Drop entries older than the window.
        cutoff = now - self.window_seconds
        while self.hits and self.hits[0] < cutoff:
            self.hits.popleft()
        if len(self.hits) >= self.limit:
            return False
        self.hits.append(now)
        return True

    @property
    def limit(self) -> int:
        # Resolved at construction via the factory below.
        raise NotImplementedError


class _FixedWindow:
    def __init__(self, *, limit: int, window_seconds: int) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self.hits: Deque[float] = deque()

    def consume(self, now: float) -> bool:
        cutoff = now - self.window_seconds
        while self.hits and self.hits[0] < cutoff:
            self.hits.popleft()
        if len(self.hits) >= self.limit:
            return False
        self.hits.append(now)
        return True


class RateLimiter:
    """A tiny registry of fixed-window buckets keyed by an arbitrary id."""

    def __init__(self) -> None:
        self._buckets: Dict[str, _FixedWindow] = {}
        self._lock = asyncio.Lock()

    async def hit(
        self,
        *,
        key: str,
        limit: int,
        window_seconds: int,
        error_code: str = "RATE_LIMITED",
        error_message: str = "Rate limit exceeded.",
    ) -> None:
        async with self._lock:
            bucket = self._buckets.get(key)
            if bucket is None or bucket.limit != limit or bucket.window_seconds != window_seconds:
                bucket = _FixedWindow(limit=limit, window_seconds=window_seconds)
                self._buckets[key] = bucket
            now = time.monotonic()
            if not bucket.consume(now):
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail={"code": error_code, "message": error_message},
                    headers={"Retry-After": str(window_seconds)},
                )


# ---------------------------------------------------------------------------
# FastAPI dependencies
# ---------------------------------------------------------------------------


_limiter = RateLimiter()


async def enforce_ip_rate_limit(request: Request) -> None:
    """Per-IP minute cap. Cheap; runs on every protected route."""
    from .config import get_settings

    settings = get_settings()
    # `client` may be None when the server is reached through a unix
    # socket (e.g. uvicorn workers in production). Fall back to a
    # stable placeholder so we still have a bucket key.
    client = request.client
    key = (client.host if client else "unknown") + ":" + str(getattr(client, "port", 0))
    await _limiter.hit(
        key=key,
        limit=settings.rate_limit_per_minute,
        window_seconds=60,
        error_code="IP_RATE_LIMITED",
        error_message="Too many requests from this IP.",
    )


async def enforce_user_ai_rate_limit(user_id: str) -> None:
    """Per-user hourly cap on the AI proxy."""
    from .config import get_settings

    settings = get_settings()
    await _limiter.hit(
        key=f"ai:{user_id}",
        limit=settings.ai_rate_limit_per_hour_per_user,
        window_seconds=3600,
        error_code="AI_RATE_LIMITED",
        error_message="AI quota exceeded for this hour.",
    )


__all__ = [
    "RateLimiter",
    "enforce_ip_rate_limit",
    "enforce_user_ai_rate_limit",
]
