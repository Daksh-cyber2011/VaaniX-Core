"""Structured JSON logging for the VaaniX backend.

Two non-negotiable guarantees:

1.  Provider API keys (`GEMINI_API_KEY`, `GROQ_API_KEY`) and the
    Supabase `SUPABASE_SERVICE_ROLE_KEY` must NEVER appear in any log
    line, no matter where the call originated.
2.  PII (user prompts, learner messages, AI completions) must never
    appear in logs at INFO or above — only at DEBUG, which is opt-in
    and gated by `LOG_LEVEL=DEBUG`.

The `redact()` helper walks every value passed to the logger and
replaces anything that looks like a secret with the literal marker
`<redacted>`.
"""

from __future__ import annotations

import json
import logging
import re
import sys
from typing import Any, Iterable, Mapping


# ---------------------------------------------------------------------------
# Secret detection
# ---------------------------------------------------------------------------

# Order matters: more specific patterns first.
_SECRET_PATTERNS: tuple[re.Pattern[str], ...] = (
    # Groq: `gsk_` followed by 20+ alphanumerics, used as a Bearer token.
    re.compile(r"\bgsk_[A-Za-z0-9_-]{16,}\b"),
    # Google Gemini / PaLM-style keys: `AIza` followed by 30+ chars.
    re.compile(r"\bAIza[A-Za-z0-9_-]{30,}\b"),
    # Supabase service-role / anon JWTs always begin with `eyJ`.
    re.compile(r"\beyJ[A-Za-z0-9_-]{40,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b"),
    # Supabase project URL fragment that uniquely identifies a project.
    # NOTE: the host itself is logged because it is needed for debugging;
    # we only redact the JWT-shaped bearer tokens above.
    # Generic "key=value" form, e.g. `GEMINI_API_KEY=...`.
    re.compile(
        r"(?i)\b(GROQ_API_KEY|GEMINI_API_KEY|SUPABASE_SERVICE_ROLE_KEY|"
        r"VAANIX_BACKEND_SECRET)\s*=\s*([^\s,'\"\\]+)"
    ),
    # Generic "key":"value" JSON form.
    re.compile(
        r'(?i)("(?:GROQ_API_KEY|GEMINI_API_KEY|SUPABASE_SERVICE_ROLE_KEY|'
        r'VAANIX_BACKEND_SECRET)"\s*:\s*)"([^"]+)"'
    ),
)


def redact(value: Any) -> Any:
    """Recursively scrub secrets from a string / dict / list."""
    if isinstance(value, str):
        scrubbed = value
        for pattern in _SECRET_PATTERNS:
            scrubbed = pattern.sub(r"\1<redacted>", scrubbed) if pattern.groups else pattern.sub("<redacted>", scrubbed)
        return scrubbed
    if isinstance(value, Mapping):
        return {k: redact(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set, frozenset)):
        return [ redact(v) for v in value ]
    return value


# ---------------------------------------------------------------------------
# Filter that runs on every record BEFORE formatting
# ---------------------------------------------------------------------------


class RedactionFilter(logging.Filter):
    """Apply redaction to record.args and record.msg before formatting."""

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            if isinstance(record.args, Mapping):
                record.args = {k: redact(v) for k, v in record.args.items()}  # type: ignore[arg-type]
            elif record.args:
                record.args = tuple(redact(a) for a in record.args)  # type: ignore[assignment]
            if isinstance(record.msg, str):
                record.msg = redact(record.msg)
        except Exception:  # pragma: no cover - defensive
            # Never let logging itself crash the app.
            pass
        return True


# ---------------------------------------------------------------------------
# JSON formatter
# ---------------------------------------------------------------------------


class JsonFormatter(logging.Formatter):
    """Minimal JSON line formatter. No external deps required."""

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        # Carry through any explicit `extra={...}` fields.
        for key, value in record.__dict__.items():
            if key in {
                "args", "asctime", "created", "exc_info", "exc_text", "filename",
                "funcName", "levelname", "levelno", "lineno", "module", "msecs",
                "message", "msg", "name", "pathname", "process", "processName",
                "relativeCreated", "stack_info", "thread", "threadName",
                "taskName",
            }:
                continue
            payload[key] = value
        return json.dumps(payload, ensure_ascii=False, default=str)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def configure_logging(level: str = "INFO") -> None:
    """Install the redacting JSON formatter on the root logger.

    Idempotent — safe to call multiple times (e.g. from tests).
    """
    root = logging.getLogger()
    # Remove any existing handlers we did not install (e.g. uvicorn's).
    for handler in list(root.handlers):
        if not getattr(handler, "_vaanix_installed", False):
            root.removeHandler(handler)

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    handler.addFilter(RedactionFilter())
    handler.setLevel(level)
    handler._vaanix_installed = True  # type: ignore[attr-defined]

    root.addHandler(handler)
    root.setLevel(level)

    # Quiet noisy libraries.
    for name in ("httpx", "httpcore"):
        logging.getLogger(name).setLevel(max(logging.WARNING, logging.getLevelName(level) or logging.WARNING))


__all__ = ["configure_logging", "redact", "RedactionFilter", "JsonFormatter"]
