"""Sync / outbox receiver.

The Flutter client keeps a local-first store of user-owned state and
queues mutations in an outbox. On reconnect it POSTs the envelope to
`/api/v1/sync/outbox`. The backend:

1.  Authenticates the user.
2.  For every operation, decides fresh-vs-duplicate via the
    idempotency store.
3.  Applies accepted operations to Supabase using the user's JWT —
    so row-level security on the cloud tables enforces that User A
    can NEVER write into User B's rows, even if a bug at the
    backend tried to.
4.  Records the response so retries are transparent.

The companion read endpoint `/api/v1/sync/snapshot` returns the
user's latest cloud state, optionally since a cursor.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status

from .config import get_settings
from .idempotency import IdempotencyResult, IdempotencyStore
from .models import (
    OutboxAck,
    OutboxEnvelope,
    OutboxOperationType,
    OutboxResult,
    SyncSnapshot,
    SyncSnapshotRequest,
)
from .security import AuthenticatedUser, require_authenticated_user
from .supabase_client import get_admin_client

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/sync", tags=["sync"])


# ---------------------------------------------------------------------------
# Per-operation handlers
#
# Every handler receives the user's JWT (forwarded to Supabase so RLS
# enforces the auth boundary) and the parsed payload. Handlers MUST be
# total functions — they either return a payload to persist, or raise
# HTTPException. They MUST NOT mutate a different user's rows.
# ---------------------------------------------------------------------------


def _postgrest_headers(user: AuthenticatedUser) -> Dict[str, str]:
    """Headers for talking to Supabase PostgREST as the user."""
    settings = get_settings()
    return {
        "Authorization": f"Bearer {user.raw_token}",
        "apikey": settings.supabase_service_role_key,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }


def _postgrest_url(path: str) -> str:
    settings = get_settings()
    base = settings.supabase_url.rstrip("/")
    # Supabase REST lives at /rest/v1/<table>
    return f"{base}/rest/v1/{path.lstrip('/')}"


async def _upsert(
    user: AuthenticatedUser, *, table: str, payload: Dict[str, Any]
) -> Dict[str, Any]:
    """Upsert one user-owned row."""
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "EMPTY_PAYLOAD", "message": "Outbox operation payload was empty."},
        )
    # Inject ownership column so a missing client-side id cannot smuggle
    # another user's row into the table.
    payload = {**payload, "user_id": user.id}

    url = _postgrest_url(f"{table}?on_conflict=user_id,id")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                url, json=payload, headers=_postgrest_headers(user)
            )
    except httpx.RequestError as e:
        log.warning("supabase_unreachable", extra={"table": table, "err": str(e)})
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "SUPABASE_UNAVAILABLE", "message": "Sync backend unreachable."},
        )
    if resp.status_code >= 400:
        log.warning(
            "supabase_rejected_op",
            extra={"table": table, "status": resp.status_code},
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={"code": "SUPABASE_REJECTED", "message": "Sync backend rejected the operation."},
        )
    body = resp.json() if resp.content else {}
    return body[0] if isinstance(body, list) and body else {"ok": True}


_HANDLERS = {
    OutboxOperationType.upsert_progress: ("user_progress", "id"),
    OutboxOperationType.upsert_mastery: ("user_mastery", "concept_id"),
    OutboxOperationType.upsert_course_state: ("user_course_state", "course_id"),
    OutboxOperationType.upsert_learn_profile: ("user_learn_profile", "user_id"),
}


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.post(
    "/outbox",
    response_model=OutboxAck,
    summary="Receive a batch of outbox operations",
)
async def receive_outbox(
    envelope: OutboxEnvelope,
    user: AuthenticatedUser = Depends(require_authenticated_user),
) -> OutboxAck:
    """Apply each operation in the envelope; de-duplicate via
    idempotency keys; return per-op acknowledgements."""
    store = IdempotencyStore(get_admin_client())
    results: List[OutboxResult] = []

    for op in envelope.operations:
        # 1. Duplicate check (per-user).
        decision: IdempotencyResult = await store.begin_or_resume(
            user_id=user.id, operation_id=op.operation_id
        )
        if not decision.accepted:
            results.append(
                OutboxResult(operation_id=op.operation_id, accepted=True,
                             error="duplicate")
            )
            continue

        handler = _HANDLERS.get(op.type)
        if handler is None:
            await store.record_response(
                user_id=user.id,
                operation_id=op.operation_id,
                response={"accepted": False, "error": "unknown_type"},
            )
            results.append(
                OutboxResult(operation_id=op.operation_id, accepted=False,
                             error="unknown_type")
            )
            continue
        table, key_column = handler
        # Ensure the upsert identifies the row by (user_id, key_column).
        row = dict(op.payload)
        if key_column in row:
            row.setdefault("id", row[key_column])
        else:
            row[key_column] = op.entity_id or f"op-{op.operation_id}"
        try:
            saved = await _upsert(user, table=table, payload=row)
        except HTTPException as e:
            await store.record_response(
                user_id=user.id,
                operation_id=op.operation_id,
                response={"accepted": False, "error": str(e.detail)},
            )
            results.append(
                OutboxResult(operation_id=op.operation_id, accepted=False,
                             error=str(e.detail.get("code", "error")))
            )
            continue

        await store.record_response(
            user_id=user.id,
            operation_id=op.operation_id,
            response={"accepted": True, "row": saved},
        )
        results.append(OutboxResult(operation_id=op.operation_id, accepted=True))

    return OutboxAck(results=results)


@router.post(
    "/snapshot",
    response_model=SyncSnapshot,
    summary="Read the latest user-owned cloud state",
)
async def get_snapshot(
    body: SyncSnapshotRequest = SyncSnapshotRequest(),
    user: AuthenticatedUser = Depends(require_authenticated_user),
) -> SyncSnapshot:
    """Return user-owned rows since [since], capped at [limit].

    Every table query is performed as the USER (not the admin client),
    so PostgREST/RLS will refuse to return any row owned by another
    user even if a backend bug tried to ask for it.
    """
    headers = _postgrest_headers(user)
    headers["Range-Unit"] = "items"
    headers["Range"] = f"0-{body.limit - 1}"

    async def _fetch(table: str) -> List[Dict[str, Any]]:
        url = _postgrest_url(table)
        params = {"order": "updated_at.desc"}
        if body.since:
            params["updated_at"] = f"gte.{body.since.isoformat()}"
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(url, params=params, headers=headers)
        except httpx.RequestError:
            return []
        if resp.status_code >= 400:
            return []
        if not resp.content:
            return []
        try:
            return resp.json()
        except ValueError:
            return []

    progress = await _fetch("user_progress?select=*&user_id=eq." + user.id)
    mastery = await _fetch("user_mastery?select=*&user_id=eq." + user.id)
    course_state = await _fetch("user_course_state?select=*&user_id=eq." + user.id)
    learn_profile = await _fetch("user_learn_profile?select=*&user_id=eq." + user.id)

    return SyncSnapshot(
        server_time=datetime.now(timezone.utc),
        progress=progress,
        mastery=mastery,
        course_state=course_state,
        learn_profile=learn_profile,
        cursor=body.since,
    )


__all__ = ["router"]
