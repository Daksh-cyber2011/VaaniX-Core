"""VaaniX backend typed settings.

Loaded once at startup from environment variables (or a local `.env`
file via `pydantic-settings`). The shape is the canonical reference
for every other backend module — never read `os.environ` directly.

CRITICAL: provider API keys (`GEMINI_API_KEY`, `GROQ_API_KEY`) and the
Supabase `SUPABASE_SERVICE_ROLE_KEY` MUST only be readable from this
module on the server. They must NEVER be exposed to the Flutter client.
"""

from functools import lru_cache
from typing import List, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Process-wide configuration.

    Values come from process environment first, then a local `.env`
    file (the latter only when present — production deployments
    typically rely on the orchestrator's env injection).
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # --- Environment ---------------------------------------------------------
    env: Literal["development", "staging", "production"] = Field(
        default="development",
        alias="VAANIX_ENV",
        description="Runtime environment. Affects log verbosity and CORS.",
    )
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = Field(
        default="INFO",
        alias="LOG_LEVEL",
    )

    # --- Security ------------------------------------------------------------
    backend_secret: str = Field(
        alias="VAANIX_BACKEND_SECRET",
        min_length=16,
        description="HMAC secret used to sign short-lived session-bound "
        "tokens issued to the Flutter client. NOT a Supabase JWT secret.",
    )

    # --- Supabase ------------------------------------------------------------
    supabase_url: str = Field(alias="SUPABASE_URL")
    supabase_service_role_key: str = Field(
        alias="SUPABASE_SERVICE_ROLE_KEY",
        description="Privileged key — must NEVER leave the backend.",
    )

    # --- Provider keys (server-only) -----------------------------------------
    gemini_api_key: str = Field(default="", alias="GEMINI_API_KEY")
    gemini_model: str = Field(default="gemini-3.8-flash", alias="GEMINI_MODEL")
    groq_api_key: str = Field(default="", alias="GROQ_API_KEY")
    groq_model: str = Field(
        default="llama-3.3-70b-versatile", alias="GROQ_MODEL"
    )

    # --- Networking ----------------------------------------------------------
    allowed_origins: List[str] = Field(
        default_factory=lambda: ["http://localhost:3000"],
        alias="ALLOWED_ORIGINS",
        description="Origins permitted to call the API from a browser. "
        "Ignored for native mobile clients (Flutter does not send "
        "Origin headers in the same way browsers do).",
    )
    rate_limit_per_minute: int = Field(default=120, alias="RATE_LIMIT_PER_MINUTE")
    ai_rate_limit_per_hour_per_user: int = Field(
        default=60, alias="AI_RATE_LIMIT_PER_HOUR_PER_USER"
    )

    # --- Validation ----------------------------------------------------------
    @field_validator("allowed_origins", mode="before")
    @classmethod
    def _split_origins(cls, v):
        """Allow `ALLOWED_ORIGINS=https://a,https://b` from the env."""
        if isinstance(v, str):
            return [s.strip() for s in v.split(",") if s.strip()]
        return v

    # --- Derived helpers -----------------------------------------------------
    @property
    def is_production(self) -> bool:
        return self.env == "production"

    @property
    def gemini_configured(self) -> bool:
        return bool(self.gemini_api_key) and not self.gemini_api_key.lower().startswith(
            "your-"
        )

    @property
    def groq_configured(self) -> bool:
        return bool(self.groq_api_key) and not self.groq_api_key.lower().startswith(
            "your-"
        )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Process-wide cached settings instance."""
    return Settings()  # type: ignore[call-arg]
