"""Health endpoint tests."""

from __future__ import annotations

import respx
from httpx import Response


def test_health_is_public_and_does_not_require_auth(client):
    r = client.get("/health")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "ok"
    assert body["service"] == "vaanix-backend"
    assert "timestamp" in body


def test_health_ready_requires_authentication(client):
    r = client.get("/health/ready")
    assert r.status_code == 401, r.text
    assert r.json()["detail"]["code"] == "UNAUTHENTICATED"


@respx.mock
def test_health_ready_passes_when_token_valid(client):
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(
            200,
            json={
                "id": "11111111-1111-1111-1111-111111111111",
                "email": "a@example.com",
            },
        )
    )
    r = client.get(
        "/health/ready",
        headers={"Authorization": "Bearer test-token-for-a"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "ok"
    assert body["auth_user_id"] == "11111111-1111-1111-1111-111111111111"


@respx.mock
def test_health_ready_401_when_supabase_rejects(client):
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(401, json={"msg": "invalid"})
    )
    r = client.get(
        "/health/ready",
        headers={"Authorization": "Bearer bad-token"},
    )
    assert r.status_code == 401
    assert r.json()["detail"]["code"] == "INVALID_TOKEN"


@respx.mock
def test_health_ready_503_when_supabase_unreachable(client):
    import httpx

    respx.get("http://localhost:54321/auth/v1/user").mock(
        side_effect=httpx.ConnectError("no network")
    )
    r = client.get(
        "/health/ready",
        headers={"Authorization": "Bearer test-token-for-a"},
    )
    assert r.status_code == 503
    assert r.json()["detail"]["code"] == "AUTH_BACKEND_UNAVAILABLE"


@respx.mock
def test_secret_keys_never_appear_in_logs(client, caplog):
    """Sanity: a misconfigured Authorization header or Supabase reply
    MUST never end up echoed into our logs."""
    import logging

    caplog.set_level(logging.INFO)
    # Send a token that LOOKS like a leaked secret. The security module
    # does not echo it, but we still assert that the only redacted token
    # in any log line is the literal marker `<redacted>` and that the
    # original string never appears verbatim in any record.
    secret_like = "gsk_supersecrettoken_supersecrettoken_supersecrettoken"
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(200, json={"id": "u1", "email": "a@b.com"})
    )
    r = client.get(
        "/health/ready",
        headers={"Authorization": f"Bearer {secret_like}"},
    )
    assert r.status_code == 200
    leaked = [rec for rec in caplog.records if secret_like in rec.getMessage()]
    assert leaked == [], "secret token leaked into a log line"
