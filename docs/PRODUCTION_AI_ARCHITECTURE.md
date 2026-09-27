# VaaniX — Production AI Architecture

How VaaniX keeps provider credentials off the mobile client, and what
the developer must configure in each environment.

---

## 1. The final request path

```text
Learn / Chat / any AI consumer
        │
        ▼
AIService                       (lib/features/ai/domain/ai_service.dart)
        │  adapterFor(AiConfig) → GroqModelAdapter
        ▼
BackendAiTransport               (lib/features/ai/data/backend_ai_transport.dart)
        │  POST {apiBaseUrl}/ai/chat   Authorization: Bearer <supabase jwt>
        ▼
VaanixApiClient                  (lib/core/api/vaanix_api_client.dart)
        │
        ▼
VaaniX Backend                   (backend/app/ai_proxy.py)
        │  1. require_authenticated_user  — validates the JWT against Supabase
        │  2. enforce_user_ai_rate_limit  — per-user hourly quota
        │  3. _call_groq / _call_gemini   — reads server-side keys
        ▼
Groq  |  Gemini                 (privileged network call, server-side only)
        │
        ▼
normalized AiResponse            (backend/app/models.py)
        │  choices[0].message.content  +  usage
        ▼
GroqModelAdapter parses it exactly like a direct Groq response
```

The Flutter app never sees a provider API key in production. The
`apiKey` argument that `GroqModelAdapter` passes into
`postChatCompletions` is an **opaque placeholder** in backend mode —
`BackendAiTransport` ignores it entirely and the backend authenticates
with the user's Supabase JWT instead.

---

## 2. Where each secret lives

| Secret | Lives in | Reaches the client? |
|---|---|---|
| `GROQ_API_KEY` | backend env only | **No** |
| `GEMINI_API_KEY` | backend env only | **No** |
| `SUPABASE_SERVICE_ROLE_KEY` | backend env only | **No** |
| `VAANIX_BACKEND_SECRET` | backend env only | **No** |
| `GROQ_MODEL` / `GEMINI_MODEL` | backend env (authoritative); client copy is advisory only | Model *name*, never a credential |
| `SUPABASE_ANON_KEY` | client `.env` | Yes — designed to be public; RLS is the enforcement boundary |
| `API_BASE_URL` | client `.env` | Yes — a URL, not a secret |

### Why direct mobile API keys are unacceptable

An APK is a public artifact. Any string constant, asset file, or
`.env` shipped inside it can be extracted by anyone who downloads the
app. A `GEMINI_API_KEY` inside the bundle is a **billable key on
someone else's account** until someone finds it. This is why
`aiServiceProvider` refuses to register a direct-provider adapter when
`AppEnvironment.isProduction` is true — see §4.

---

## 3. Environment configuration

### Client (`assets/env/.env`)

```dotenv
APP_ENV=production
API_BASE_URL=https://api.vaanix.app/api/v1
VAANIX_USE_BACKEND_AI=true
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=ey...anon-key...
```

A **production** client `.env` must NOT contain `GROQ_API_KEY` or
`GEMINI_API_KEY`. `AppEnvironment.hasDirectProviderKeys` exists so the
Settings screen can surface a warning if one is ever found.

### Backend (`backend/.env`)

See `backend/.env.example`. The required set is:

| Variable | Purpose |
|---|---|
| `VAANIX_BACKEND_SECRET` | Backend signing secret. ≥16 chars. |
| `SUPABASE_URL` | Supabase project URL. |
| `SUPABASE_SERVICE_ROLE_KEY` | Privileged key. Backend-only. |
| `GROQ_API_KEY` / `GROQ_MODEL` | Groq credentials + model. |
| `GEMINI_API_KEY` / `GEMINI_MODEL` | Gemini credentials + model. |
| `VAANIX_ENV` | `development` \| `staging` \| `production` |

---

## 4. Development vs production

| | Development | Production |
|---|---|---|
| Flag | `VAANIX_USE_BACKEND_AI=false` (or unset) | `VAANIX_USE_BACKEND_AI=true` **and** `APP_ENV=production` |
| AI path | Flutter → Groq/Gemini directly | Flutter → VaaniX backend → Groq/Gemini |
| Client holds a provider key | Yes (dev only) | **No** |
| Groq / Gemini adapters registered | Only when the client-side key is present | Always (the *backend* holds the key) |
| What happens if a stray key is in the production `.env` | — | The direct adapter is **not registered**. `allowDirectProvider` is `false`, so the key is inert. |

This is deliberately asymmetric:

- **Development** keeps the direct adapters so an engineer can iterate
  against a provider without standing up the backend.
- **Production** never registers a direct adapter, so there is no code
  path that could send a client-held key to a provider. There is also
  **no silent fallback** from backend to direct: if the backend is
  unreachable, the request fails and degrades to the offline tutor.
  Falling back to a direct provider would require shipping a key, which
  is exactly the thing this architecture exists to prevent.

The relevant code is `aiServiceProvider` in
`lib/features/ai/presentation/providers/ai_providers.dart`.

---

## 5. Model selection

The backend is authoritative. The client sends `provider` and `model`,
but the backend resolves the actual model from its own configuration
(`config.groq_model` / `config.gemini_model`). `AiRequest` validates
`model` as a bounded non-empty string and caps `max_tokens` at 8192, so
a client cannot use VaaniX as an unrestricted proxy to an arbitrary or
private upstream model.

---

## 6. Streaming

**Non-streaming is fully implemented. Streaming is not.**

`GroqModelAdapter.stream()` still exists and is unchanged — it routes
through `GroqHttpTransport`, which in backend mode is
`BackendAiTransport`. `BackendAiTransport` returns a single 200 with the
complete body, so the adapter's SSE line parser finds no `data:` lines
and immediately yields a terminal `done` delta. The result is a correct
(non-streamed) answer delivered through the streaming call path, but the
tokens do not arrive incrementally.

Adding real streaming would mean teaching the backend to relay
Server-Sent Events and teaching `VaanixApiClient` to expose the
response body as a stream. That is a self-contained follow-up; it is
deliberately not faked here.

---

## 7. Error normalization

The backend never returns a raw provider payload. Failures are mapped
to a stable `{"code": ..., "message": ...}` envelope:

| Upstream condition | Backend HTTP | Code |
|---|---|---|
| provider 401/403 | 502 | `PROVIDER_AUTH` |
| provider 429 | 429 | `PROVIDER_RATE_LIMITED` |
| provider 5xx | 502 | `PROVIDER_ERROR` |
| provider unreachable | 502 | `PROVIDER_UNREACHABLE` |
| provider returned non-JSON / no choices | 502 | `PROVIDER_MALFORMED` |
| provider not configured on backend | 503 | `PROVIDER_UNCONFIGURED` |
| missing / invalid bearer token | 401 | `UNAUTHENTICATED` / `INVALID_TOKEN` |
| request too large / malformed | 400 / 422 | validation error |

`BackendAiTransport` translates those codes back into the adapter's
typed exceptions (`AuthApiException`, `AuthException`,
`TimeoutException`, `ServerException`) so the existing retry
classification keeps working. Notably a rate-limit becomes
`AuthApiException`, which `GroqModelAdapter.isTransientAiError`
classifies as **non-transient** — retrying a quota rejection would
hammer the provider.

Provider error bodies are never echoed verbatim: the 401/403 branch
carries only the status code, because providers have been observed to
echo partial key fragments in error payloads.

---

## 8. Rate limiting

Two independent layers, neither of which the client can influence:

- **Per IP**, `RATE_LIMIT_PER_MINUTE` (default 120/min), applied by
  middleware to every `/api/*` route.
- **Per authenticated user**, `AI_RATE_LIMIT_PER_HOUR_PER_USER`
  (default 60/hour), applied to `/api/v1/ai/chat` after the identity is
  resolved — so one account cannot exhaust the shared provider quota by
  rotating IPs.

---

## 9. Authentication

`require_authenticated_user` (`backend/app/security.py`):

1. Extracts the `Authorization: Bearer <jwt>` header.
2. Calls Supabase `GET /auth/v1/user` with that JWT.
3. Returns an `AuthenticatedUser` whose `.id` is the Supabase user id.

The user id is **derived from the validated token only**. A
client-supplied `user_id` in the request body is ignored, and the
`user_id` written to Supabase is force-overwritten server-side
(`payload = {**payload, "user_id": user.id}`) so a crafted body cannot
write into another user's rows. The raw JWT is forwarded to PostgREST
so row-level security also applies on the way in and out.

---

## 10. Running the backend

```powershell
cd backend
python -m pip install -r requirements.txt
Copy-Item .env.example .env    # then fill in real values
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- `GET /health` — public liveness probe.
- `GET /health/ready` — readiness; 200 means the auth backend answered.
- `GET /docs` — OpenAPI UI, disabled when `VAANIX_ENV=production`.

> No backend has been deployed. The commands above describe a local
> run that has been **source-validated**; it has not been executed
> against live Supabase or live provider credentials.

---

## 11. Local development without a backend

Leave `VAANIX_USE_BACKEND_AI` unset and put a real key in
`assets/env/.env` with `APP_ENV=development`. The direct Groq and
Gemini adapters then register and behave exactly as they did before the
backend existed. This is the only supported configuration in which a
provider key lives on the device, and it must never be shipped.

---

## 12. Verification status

| Claim | Status |
|---|---|
| Production routing selects `BackendAiTransport` | **Verified by unit test** (`test/features/ai/provider_routing_test.dart`) |
| Production flavor refuses direct adapters | **Verified by unit test** |
| Transport never forwards a provider key | **Verified by unit test** |
| Backend never returns a provider key | **Verified by backend test** (source-validated only) |
| Backend runs and serves real traffic | **Not runtime-verified** — no deployment, no live credentials |
| Streaming through the backend | **Not implemented** — see §6 |
