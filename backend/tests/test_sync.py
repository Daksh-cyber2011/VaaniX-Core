"""Sync / outbox tests.

These tests cover:

* A legitimate batch is accepted; idempotency store sees the
  operation IDs.
* A second envelope with the same operation IDs is treated as a
  duplicate (no second DB write).
* An unknown operation type is rejected per-op (not a whole-batch
  failure).
* `snapshot` reads as the user (not as admin) so RLS can refuse
  cross-user rows.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import respx
from httpx import Response


def _auth(user_id: str = "user-a"):
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(
            200, json={"id": user_id, "email": f"{user_id}@example.com"}
        )
    )


def _captured_postgrest_requests():
    """Return the list of PostgREST POSTs the sync endpoint issued."""
    captured = []
    for route in respx.routes:
        if not str(route.url).endswith(("/user_progress", "/user_mastery",
                                          "/user_course_state", "/user_learn_profile")):
            continue
        if "rest/v1" not in str(route.url):
            continue
        captured.append(route)
    return captured


@respx.mock
def test_outbox_accepts_legitimate_batch_and_upserts(client):
    _auth("user-a")
    respx.post(
        "http://localhost:54321/rest/v1/user_progress?on_conflict=user_id,id"
    ).mock(return_value=Response(200, json=[{"id": "p1", "user_id": "user-a"}]))

    r = client.post(
        "/api/v1/sync/outbox",
        headers={"Authorization": "Bearer t-a"},
        json={
            "operations": [
                {
                    "operation_id": "op-1",
                    "type": "upsert_progress",
                    "entity_id": "p1",
                    "payload": {"id": "p1", "language": "hi"},
                    "created_at": datetime.now(timezone.utc).isoformat(),
                }
            ]
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["results"][0]["operation_id"] == "op-1"
    assert body["results"][0]["accepted"] is True


@respx.mock
def test_outbox_rejects_unknown_type_per_op(client):
    _auth("user-b")
    r = client.post(
        "/api/v1/sync/outbox",
        headers={"Authorization": "Bearer t-b"},
        json={
            "operations": [
                {
                    "operation_id": "op-2",
                    "type": "delete_everything",  # not in the allow-list
                    "payload": {},
                    "created_at": datetime.now(timezone.utc).isoformat(),
                }
            ]
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["results"][0]["accepted"] is False
    assert body["results"][0]["error"] == "unknown_type"


@respx.mock
def test_outbox_dedupes_second_arrival(client):
    """The same operation_id arriving twice MUST NOT cause a second
    upsert to Supabase. Without dedup, the second call would POST
    again — and the test would see two PostgREST hits."""
    _auth("user-c")
    route = respx.post(
        "http://localhost:54321/rest/v1/user_progress?on_conflict=user_id,id"
    ).mock(return_value=Response(200, json=[{"id": "p1", "user_id": "user-c"}]))

    envelope = {
        "operations": [
            {
                "operation_id": "op-dup",
                "type": "upsert_progress",
                "entity_id": "p1",
                "payload": {"id": "p1", "language": "hi"},
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
        ]
    }
    r1 = client.post(
        "/api/v1/sync/outbox",
        headers={"Authorization": "Bearer t-c"},
        json=envelope,
    )
    r2 = client.post(
        "/api/v1/sync/outbox",
        headers={"Authorization": "Bearer t-c"},
        json=envelope,
    )
    assert r1.status_code == 200 and r2.status_code == 200
    # Exactly one PostgREST POST was issued.
    assert route.call_count == 1, (
        f"duplicate outbox operation produced {route.call_count} DB writes; "
        "expected exactly 1"
    )


@respx.mock
def test_outbox_requires_auth(client):
    r = client.post(
        "/api/v1/sync/outbox",
        json={"operations": []},
    )
    assert r.status_code == 401


@respx.mock
def test_snapshot_returns_only_rows_visible_to_the_user(client):
    _auth("user-d")
    # Snapshot reads as the user. The PostgREST request MUST carry the
    # user JWT, not the service-role key — this is how RLS is honored.
    respx.get(
        "http://localhost:54321/rest/v1/user_progress",
    ).mock(return_value=Response(200, json=[{"id": "p1", "user_id": "user-d"}]))
    respx.get(
        "http://localhost:54321/rest/v1/user_mastery",
    ).mock(return_value=Response(200, json=[]))
    respx.get(
        "http://localhost:54321/rest/v1/user_course_state",
    ).mock(return_value=Response(200, json=[]))
    respx.get(
        "http://localhost:54321/rest/v1/user_learn_profile",
    ).mock(return_value=Response(200, json=[]))

    r = client.post(
        "/api/v1/sync/snapshot",
        headers={"Authorization": "Bearer t-d"},
        json={},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["progress"] == [{"id": "p1", "user_id": "user-d"}]
    assert body["mastery"] == []

    # Sanity — every PostgREST call carried the user JWT.
    for route in respx.routes:
        if not str(route.url).startswith("http://localhost:54321/rest/v1/"):
            continue
        for call in route.calls:
            auth = call.request.headers.get("authorization", "")
            assert auth.startswith("Bearer t-d"), (
                f"snapshot used {auth!r} instead of the user JWT — this "
                "would bypass RLS"
            )
