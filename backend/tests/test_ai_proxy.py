"""AI proxy tests — secret hygiene + provider dispatch."""

from __future__ import annotations

import os

import pytest
import respx
from httpx import Response


@pytest.fixture(autouse=True)
def _force_provider_keys(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test_real_abcdef1234567890")
    monkeypatch.setenv("GEMINI_API_KEY", "AIzaSyTest-real-key-value-1234567890")
    monkeypatch.setenv("GROQ_MODEL", "llama-3.3-70b-versatile")
    monkeypatch.setenv("GEMINI_MODEL", "gemini-3.8-flash")
    # Reload settings cache so the new env values are picked up.
    from app import config as config_module
    config_module.get_settings.cache_clear()
    yield
    config_module.get_settings.cache_clear()


@respx.mock
def test_groq_chat_success_returns_normalized_response(client):
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(200, json={"id": "user-1", "email": "a@b.com"})
    )
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=Response(
            200,
            json={
                "id": "cmpl-1",
                "model": "llama-3.3-70b-versatile",
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": "namaste"},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {
                    "prompt_tokens": 5,
                    "completion_tokens": 1,
                    "total_tokens": 6,
                },
            },
        )
    )
    r = client.post(
        "/api/v1/ai/chat",
        headers={"Authorization": "Bearer t1"},
        json={
            "provider": "groq",
            "model": "llama-3.3-70b-versatile",
            "messages": [{"role": "user", "content": "hi"}],
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["provider"] == "groq"
    assert body["choices"][0]["message"]["content"] == "namaste"
    assert body["usage"]["total_tokens"] == 6


@respx.mock
def test_ai_chat_rejects_unauthenticated(client):
    r = client.post(
        "/api/v1/ai/chat",
        json={
            "provider": "groq",
            "model": "m",
            "messages": [{"role": "user", "content": "x"}],
        },
    )
    assert r.status_code == 401


@respx.mock
def test_ai_chat_returns_429_when_provider_rate_limited(client):
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(200, json={"id": "user-2"})
    )
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=Response(
            429,
            json={"error": {"message": "rate_limit_exceeded"}},
        )
    )
    r = client.post(
        "/api/v1/ai/chat",
        headers={"Authorization": "Bearer t2"},
        json={
            "provider": "groq",
            "model": "m",
            "messages": [{"role": "user", "content": "x"}],
        },
    )
    assert r.status_code == 429
    assert r.json()["detail"]["code"] == "PROVIDER_RATE_LIMITED"


@respx.mock
def test_ai_chat_handles_provider_5xx(client):
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(200, json={"id": "user-3"})
    )
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=Response(503, text="upstream down")
    )
    r = client.post(
        "/api/v1/ai/chat",
        headers={"Authorization": "Bearer t3"},
        json={
            "provider": "groq",
            "model": "m",
            "messages": [{"role": "user", "content": "x"}],
        },
    )
    assert r.status_code == 502
    assert r.json()["detail"]["code"] == "PROVIDER_ERROR"


@respx.mock
def test_ai_chat_handles_malformed_provider_response(client):
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(200, json={"id": "user-4"})
    )
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=Response(200, text="not json")
    )
    r = client.post(
        "/api/v1/ai/chat",
        headers={"Authorization": "Bearer t4"},
        json={
            "provider": "groq",
            "model": "m",
            "messages": [{"role": "user", "content": "x"}],
        },
    )
    assert r.status_code == 502
    assert r.json()["detail"]["code"] == "PROVIDER_MALFORMED"


@respx.mock
def test_ai_chat_503_when_provider_not_configured(client, monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "")
    from app import config as config_module
    config_module.get_settings.cache_clear()
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(200, json={"id": "user-5"})
    )
    r = client.post(
        "/api/v1/ai/chat",
        headers={"Authorization": "Bearer t5"},
        json={
            "provider": "groq",
            "model": "m",
            "messages": [{"role": "user", "content": "x"}],
        },
    )
    assert r.status_code == 503
    assert r.json()["detail"]["code"] == "PROVIDER_UNCONFIGURED"


@respx.mock
def test_ai_chat_secret_hygiene(caplog, client):
    """Provider keys MUST NOT leak into logs or response bodies."""
    import logging

    caplog.set_level(logging.INFO)
    respx.get("http://localhost:54321/auth/v1/user").mock(
        return_value=Response(200, json={"id": "user-6"})
    )
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=Response(
            200,
            json={
                "choices": [
                    {
                        "index": 0,
                        "message": {
                            "role": "assistant",
                            "content": "ok",
                        },
                        "finish_reason": "stop",
                    }
                ]
            },
        )
    )
    r = client.post(
        "/api/v1/ai/chat",
        headers={"Authorization": "Bearer t6"},
        json={
            "provider": "groq",
            "model": "m",
            "messages": [{"role": "user", "content": "x"}],
        },
    )
    assert r.status_code == 200
    body_text = r.text
    assert "gsk_test_real" not in body_text
    assert "AIzaSyTest" not in body_text
    for rec in caplog.records:
        assert "gsk_test_real" not in rec.getMessage()
        assert "AIzaSyTest" not in rec.getMessage()
