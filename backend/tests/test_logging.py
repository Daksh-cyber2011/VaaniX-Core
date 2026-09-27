"""Tests for the logging / redaction layer."""

from __future__ import annotations

from app.logging_config import redact


def test_redact_string_with_groq_key():
    raw = "Authorization: Bearer gsk_abcdefghijklmnopqrstuvwxyz0123456789"
    out = redact(raw)
    assert "gsk_abcdefghijklmnopqrstuvwxyz" not in out
    assert "<redacted>" in out


def test_redact_string_with_gemini_key():
    raw = "key=AIzaSyDUMMY_dummy_dummy_dummy_dummy_dummy_xyz"
    out = redact(raw)
    assert "AIzaSyDUMMY" not in out


def test_redact_string_with_supabase_jwt():
    raw = (
        "eyJhbGciOiJIUzI1NiJ9."
        "eyJzdWIiOiJ1c2VyLWEtYWJjMTIzNDU2Nzg5MCJ9."
        "abcdef0123456789-_abcdef0123456789-_abcdef0123456789"
    )
    out = redact(raw)
    assert "abcdef0123456789-_abcdef0123456789-_abcdef0123456789" not in out


def test_redact_dict_recursively():
    raw = {
        "user": "u",
        "GROQ_API_KEY": "gsk_supersecretvalue_supersecretvalue_123",
        "nested": {"GEMINI_API_KEY": "AIzaSyA-real-key-value-1234567890"},
    }
    out = redact(raw)
    assert out["GROQ_API_KEY"] == "<redacted>"
    assert out["nested"]["GEMINI_API_KEY"] == "<redacted>"
    assert out["user"] == "u"


def test_redact_list_recursively():
    raw = ["hi", {"GEMINI_API_KEY": "AIzaSyA-real-key-value-1234567890"}]
    out = redact(raw)
    assert out[0] == "hi"
    assert out[1]["GEMINI_API_KEY"] == "<redacted>"


def test_redact_passes_through_non_strings():
    assert redact(42) == 42
    assert redact(None) is None
    assert redact(True) is True
