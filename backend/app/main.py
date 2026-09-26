"""FastAPI application entry point.

Run locally:
    uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000

Environment is loaded from `.env` (see `backend/.env.example`).
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .ai_proxy import router as ai_router
from .config import get_settings
from .health import router as health_router
from .logging_config import configure_logging
from .rate_limit import enforce_ip_rate_limit
from .supabase_client import reset_admin_client_cache
from .sync_router import router as sync_router
from .users_router import router as users_router

log = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    configure_logging(settings.log_level)
    log.info(
        "backend_boot",
        extra={
            "env": settings.env,
            "providers": {
                "groq": settings.groq_configured,
                "gemini": settings.gemini_configured,
            },
        },
    )
    yield
    reset_admin_client_cache()
    log.info("backend_shutdown")


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(settings.log_level)

    app = FastAPI(
        title="VaaniX Backend",
        version="0.1.0",
        lifespan=lifespan,
        # Disable the default `/docs` only when in production; development
        # benefits from being able to point a browser at /docs.
        docs_url="/docs" if not settings.is_production else None,
        redoc_url=None,
    )

    if settings.allowed_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.allowed_origins,
            allow_credentials=False,
            allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            allow_headers=["Authorization", "Content-Type"],
            max_age=3600,
        )

    # Routes
    app.include_router(health_router)
    app.include_router(users_router)
    app.include_router(ai_router)
    app.include_router(sync_router)

    @app.middleware("http")
    async def _per_ip_rate_limit(request, call_next):
        # Apply only to authenticated endpoints — public health probes
        # must remain reachable from liveness checks at any rate.
        path = request.url.path
        if path.startswith("/api/"):
            await enforce_ip_rate_limit(request)
        return await call_next(request)

    return app


app = create_app()


__all__ = ["app", "create_app"]
