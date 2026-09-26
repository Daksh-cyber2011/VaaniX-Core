"""Pydantic models for the public HTTP surface.

Every shape that crosses the wire lives here. The Flutter client's
generated / hand-rolled model types must match these.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: str
    version: str
    timestamp: datetime


# ---------------------------------------------------------------------------
# AI proxy
# ---------------------------------------------------------------------------


class AiProvider(str, Enum):
    groq = "groq"
    gemini = "gemini"


class AiRole(str, Enum):
    system = "system"
    user = "user"
    assistant = "assistant"


class AiMessage(BaseModel):
    role: AiRole
    content: str = Field(min_length=0, max_length=20000)


class AiRequest(BaseModel):
    """The VaaniX AI gateway contract — identical to what the Flutter
    adapters currently send over the wire to Groq / Gemini directly.

    Keeping the contract shape identical means the Flutter client can
    toggle between direct-provider mode (development) and the
    VaaniX-backend mode (production) without changing call sites.
    """

    model_config = ConfigDict(extra="forbid")

    provider: AiProvider
    model: str = Field(min_length=1, max_length=200)
    messages: List[AiMessage] = Field(min_length=1, max_length=200)
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    max_tokens: int = Field(default=1024, ge=1, le=8192)
    stream: bool = False
    # Optional bounded snapshot of the learner's curriculum state. We
    # never echo this back in logs.
    learning_context: Optional[str] = Field(default=None, max_length=4000)


class AiUsage(BaseModel):
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


class AiChoice(BaseModel):
    index: int
    message: AiMessage
    finish_reason: Optional[str] = None


class AiResponse(BaseModel):
    provider: AiProvider
    model: str
    choices: List[AiChoice]
    usage: Optional[AiUsage] = None


# ---------------------------------------------------------------------------
# Sync / outbox
# ---------------------------------------------------------------------------


class OutboxOperationType(str, Enum):
    upsert_progress = "upsert_progress"
    upsert_mastery = "upsert_mastery"
    upsert_course_state = "upsert_course_state"
    upsert_learn_profile = "upsert_learn_profile"


class OutboxOperation(BaseModel):
    """A single pending mutation from the Flutter outbox."""

    operation_id: str = Field(min_length=8, max_length=64,
                              description="Client-generated UUID, idempotency key.")
    type: OutboxOperationType
    entity_id: Optional[str] = Field(default=None, max_length=128)
    payload: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime


class OutboxEnvelope(BaseModel):
    """A batch of operations sent by the Flutter client in one round-trip."""

    operations: List[OutboxOperation] = Field(min_length=1, max_length=50)


class OutboxResult(BaseModel):
    operation_id: str
    accepted: bool
    error: Optional[str] = None


class OutboxAck(BaseModel):
    results: List[OutboxResult]


class SyncSnapshotRequest(BaseModel):
    """Pull request for the latest cloud-owned state for the user."""
    since: Optional[datetime] = None
    limit: int = Field(default=100, ge=1, le=500)


class SyncSnapshot(BaseModel):
    server_time: datetime
    progress: List[Dict[str, Any]] = Field(default_factory=list)
    mastery: List[Dict[str, Any]] = Field(default_factory=list)
    course_state: List[Dict[str, Any]] = Field(default_factory=list)
    learn_profile: List[Dict[str, Any]] = Field(default_factory=list)
    cursor: Optional[datetime] = None


# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------


class UserProfile(BaseModel):
    id: str
    email: Optional[str] = None
    created_at: datetime
    # VaaniX-specific columns live on the public.users table; mirror
    # only what the Flutter client legitimately needs.
    display_name: Optional[str] = None
    preferred_language: Optional[str] = None
