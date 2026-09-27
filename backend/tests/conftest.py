"""Shared test fixtures.

These tests pin the backend's contract — the actual Supabase and
provider HTTP traffic is faked via `respx` so they run on any
machine, with no live credentials required.
"""

from __future__ import annotations

import os

# Ensure required env vars exist BEFORE Settings() is constructed.
os.environ.setdefault("VAANIX_BACKEND_SECRET", "test-secret-32-characters-long")
os.environ.setdefault("SUPABASE_URL", "http://localhost:54321")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "eyJhbGciOiJIUzI1NiJ9.service.test")
os.environ.setdefault("VAANIX_ENV", "development")

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.supabase_client import reset_admin_client_cache


@pytest.fixture(autouse=True)
def _reset_state():
    """Drop cached settings and the admin client between tests."""
    from app import config as config_module
    config_module.get_settings.cache_clear()
    reset_admin_client_cache()
    yield
    config_module.get_settings.cache_clear()
    reset_admin_client_cache()


@pytest.fixture
def app():
    return create_app()


@pytest.fixture
def client(app):
    return TestClient(app)


def bearer(user_id: str = "user-a") -> dict:
    return {"Authorization": f"Bearer test-token-for-{user_id}"}
