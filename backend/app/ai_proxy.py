"""Server-side AI proxy.

Routes:
    POST /api/v1/ai/chat  — proxy a chat completion through the chosen
                             provider. Authenticates the user, enforces
                             per-user hourly quota, normalises the
                             response, and NEVER echoes provider secrets.

The proxy is the single point where provider keys are read. The
Flutter client in production does NOT carry provider keys at all —
this endpoint speaks for it. The contract is intentionally identical
to what the Flutter adapters currently send to Groq / Gemini directly,
so the same Dart call sites toggle between direct and proxied modes
based purely on `VAANIX_API_BASE_URL`.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List

import httpx
from fastapi import APIRouter, Depends, HTTPException, status

from .config import get_settings
from .models import (
    AiMessage,
    AiProvider,
    AiRequest,
    AiResponse,
    AiRole,
    AiUsage,
)
from .rate_limit import enforce_user_ai_rate_limit
from .security import AuthenticatedUser, require_authenticated_user

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/ai", tags=["ai"])


# ---------------------------------------------------------------------------
# Provider dispatch
# ---------------------------------------------------------------------------


class _ProviderError(HTTPException):
    """Provider-shaped error mapped to a public HTTP response."""

    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(
            status_code=status_code,
            detail={"code": code, "message": message},
        )


async def _call_groq(req: AiRequest) -> AiResponse:
    settings = get_settings()
    if not settings.groq_configured:
        raise _ProviderError(503, "PROVIDER_UNCONFIGURED", "Groq is not configured on this backend.")
    url = "https://api.groq.com/openai/v1/chat/completions"
    payload = {
        "model": req.model,
        "messages": [_openai_message(m) for m in req.messages],
        "temperature": req.temperature,
        "max_tokens": req.max_tokens,
        "stream": False,
    }
    headers = {
        "Authorization": f"Bearer {settings.groq_api_key}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=payload, headers=headers)
    except httpx.RequestError as e:
        log.warning("groq_unreachable", extra={"err": str(e)})
        raise _ProviderError(502, "PROVIDER_UNREACHABLE", "Groq is currently unreachable.")
    return _parse_openai_compatible(resp, AiProvider.groq, req.model)


async def _call_gemini(req: AiRequest) -> AiResponse:
    settings = get_settings()
    if not settings.gemini_configured:
        raise _ProviderError(503, "PROVIDER_UNCONFIGURED", "Gemini is not configured on this backend.")
    # Gemini's REST API requires the model name in the URL path.
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/{req.model}"
        f":generateContent?key={settings.gemini_api_key}"
    )
    payload = {
        "contents": _gemini_contents(req.messages),
        "generationConfig": {
            "temperature": req.temperature,
            "maxOutputTokens": req.max_tokens,
        },
    }
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=payload)
    except httpx.RequestError as e:
        log.warning("gemini_unreachable", extra={"err": str(e)})
        raise _ProviderError(502, "PROVIDER_UNREACHABLE", "Gemini is currently unreachable.")
    return _parse_gemini(resp, req.model)


def _openai_message(m: AiMessage) -> Dict[str, str]:
    return {"role": m.role.value, "content": m.content}


def _gemini_contents(messages: List[AiMessage]) -> List[Dict[str, Any]]:
    """Collapse system+user turns into Gemini's `contents` shape.

    Gemini expects a `system_instruction` separately from the user/assistant
    turn history. We emit at most one system_instruction (the first
    system message if any) and pass the remaining turns as `contents`.
    """
    system_text = ""
    contents: List[Dict[str, Any]] = []
    for m in messages:
        if m.role == AiRole.system:
            if not system_text:
                system_text = m.content
            continue
        contents.append(
            {
                "role": "user" if m.role == AiRole.user else "model",
                "parts": [{"text": m.content}],
            }
        )
    if system_text:
        return [{"role": "user", "parts": [{"text": system_text}]}, *contents]
    return contents


def _parse_openai_compatible(resp: httpx.Response, provider: AiProvider, model: str) -> AiResponse:
    """Groq's response shape matches the OpenAI chat-completion shape."""
    if resp.status_code == 401:
        raise _ProviderError(502, "PROVIDER_AUTH", "Provider rejected the backend credentials.")
    if resp.status_code == 429:
        raise _ProviderError(429, "PROVIDER_RATE_LIMITED", "Provider quota exhausted — please retry.")
    if resp.status_code == 400:
        # 400 from OpenAI-compatible APIs is usually a context-length or
        # malformed-prompt issue. Echo a sanitised message back.
        body_text = (resp.text or "")[:512]
        raise _ProviderError(400, "PROVIDER_BAD_REQUEST", body_text or "Provider rejected the request.")
    if resp.status_code >= 500:
        raise _ProviderError(502, "PROVIDER_ERROR", "Provider returned a server error.")
    if resp.status_code >= 400:
        raise _ProviderError(resp.status_code, "PROVIDER_REJECTED", "Provider rejected the request.")

    try:
        data = resp.json()
    except ValueError:
        raise _ProviderError(502, "PROVIDER_MALFORMED", "Provider returned a non-JSON response.")

    choices_raw = data.get("choices") or []
    if not isinstance(choices_raw, list):
        raise _ProviderError(502, "PROVIDER_MALFORMED", "Provider returned malformed `choices`.")
    choices = []
    for idx, choice in enumerate(choices_raw):
        if not isinstance(choice, dict):
            continue
        msg = choice.get("message") or {}
        text = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(text, str):
            continue
        choices.append({
            "index": choice.get("index", idx),
            "message": {"role": "assistant", "content": text},
            "finish_reason": choice.get("finish_reason"),
        })
    if not choices:
        raise _ProviderError(502, "PROVIDER_MALFORMED", "Provider returned no assistant content.")
    usage = data.get("usage")
    usage_model = None
    if isinstance(usage, dict):
        try:
            usage_model = {
                "prompt_tokens": int(usage.get("prompt_tokens", 0)),
                "completion_tokens": int(usage.get("completion_tokens", 0)),
                "total_tokens": int(usage.get("total_tokens", 0)),
            }
        except (TypeError, ValueError):
            usage_model = None
    return AiResponse(
        provider=provider,
        model=model,
        choices=choices,
        usage=usage_model,
    )


def _parse_gemini(resp: httpx.Response, model: str) -> AiResponse:
    """Translate Gemini's `generateContent` response into AiResponse."""
    if resp.status_code == 400:
        body_text = (resp.text or "")[:512]
        raise _ProviderError(400, "PROVIDER_BAD_REQUEST", body_text or "Gemini rejected the request.")
    if resp.status_code in (401, 403):
        raise _ProviderError(502, "PROVIDER_AUTH", "Gemini rejected the backend credentials.")
    if resp.status_code == 429:
        raise _ProviderError(429, "PROVIDER_RATE_LIMITED", "Gemini quota exhausted.")
    if resp.status_code >= 500:
        raise _ProviderError(502, "PROVIDER_ERROR", "Gemini returned a server error.")
    if resp.status_code >= 400:
        raise _ProviderError(resp.status_code, "PROVIDER_REJECTED", "Gemini rejected the request.")
    try:
        data = resp.json()
    except ValueError:
        raise _ProviderError(502, "PROVIDER_MALFORMED", "Gemini returned a non-JSON response.")
    candidates = data.get("candidates") or []
    if not isinstance(candidates, list) or not candidates:
        raise _ProviderError(502, "PROVIDER_MALFORMED", "Gemini returned no candidates.")
    choices = []
    for idx, c in enumerate(candidates):
        if not isinstance(c, dict):
            continue
        content = c.get("content") or {}
        parts = content.get("parts") if isinstance(content, dict) else None
        text = ""
        if isinstance(parts, list):
            for p in parts:
                if isinstance(p, dict) and isinstance(p.get("text"), str):
                    text += p["text"]
        if not text:
            continue
        choices.append({
            "index": idx,
            "message": {"role": "assistant", "content": text},
            "finish_reason": c.get("finishReason"),
        })
    if not choices:
        raise _ProviderError(502, "PROVIDER_MALFORMED", "Gemini returned no text content.")
    usage_meta = data.get("usageMetadata")
    usage_model = None
    if isinstance(usage_meta, dict):
        try:
            pt = int(usage_meta.get("promptTokenCount", 0))
            ct = int(usage_meta.get("candidatesTokenCount", 0))
            tt = int(usage_meta.get("totalTokenCount", pt + ct))
            usage_model = {"prompt_tokens": pt, "completion_tokens": ct, "total_tokens": tt}
        except (TypeError, ValueError):
            usage_model = None
    return AiResponse(
        provider=AiProvider.gemini,
        model=model,
        choices=choices,
        usage=usage_model,
    )


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.post(
    "/chat",
    response_model=AiResponse,
    summary="Server-side AI chat proxy",
)
async def ai_chat(
    body: AiRequest,
    user: AuthenticatedUser = Depends(require_authenticated_user),
) -> AiResponse:
    """Forward an AI chat request to the chosen provider.

    The route is the single trust boundary that decides whether the
    user is allowed to talk to a provider at all (auth) and how often
    (rate limit). Provider keys are read server-side only; the response
    body never carries them.
    """
    # Per-user hourly quota. Enforced here so a single account cannot
    # burn the provider's quota regardless of IP.
    await enforce_user_ai_rate_limit(user.id)

    if body.provider == AiProvider.groq:
        return await _call_groq(body)
    if body.provider == AiProvider.gemini:
        return await _call_gemini(body)
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail={"code": "UNKNOWN_PROVIDER", "message": f"Unknown provider: {body.provider}"},
    )


__all__ = ["router"]
