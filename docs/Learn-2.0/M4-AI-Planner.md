# Learn Mode 2.0 — M4: Gemini AI Planner

Milestone: M4 of the Learn Mode 2.0 transformation (see
`docs/Audits/Learn-2.0-M0-Audit.md` §12 for the plan and gap map).
Status: **COMPLETE** (static validation suite green; `flutter test`
remains a user-machine step, as documented in M0–M3).

---

## 1. What M4 delivers

The heart of Learn Mode now beats: the Gemini planner is live behind
the M1 `LearningPlanner` contract, consuming the structured learner
state and producing validated, grounded plans. The full Master Brief
§36/§60 degradation chain is wired end to end:

```
PlannerContext (M1 digest: level, goal, mastered, weak, review queue,
                diagnostic, mistakes, minutes)
        │
        ▼
GeminiPlanner ──► structured prompts (§62) ──► one Gemini call
        │                                       (15 RPM shared budget)
        ▼
AiPlanParser (§14 untrusted-output boundary)
        │  drop: unknown concepts / wrong language / unsupported kinds /
        │       out-of-range difficulty / bad anchors / empty reasons
        ▼
ValidatingPlanner facade  ──failure or nothing grounded──►  fallback
        │ Right(plan, source: ai)                            │
        │                                                    ▼
        │                                     CachedPlanPlanner (≤7 days)
        │                                       │ miss/stale ──►
        │                                       ▼
        │                                  DeterministicPlanner (M1)
        ▼
activeLearningPlanProvider (source label: ai / cached / deterministic)
```

An AI outage, a missing API key, rate limiting, or pure model garbage
each degrade ONE hop — never a crash, never a blank screen, never a
faked AI answer (§60).

## 2. New modules (all additive, nothing replaced)

### `spine/planner_prompt.dart` (pure Dart) — §62 structured prompts
- `buildPlannerSystemPrompt`: pedagogy + grounding rules + the strict
  JSON output schema. Only activity kinds the build actually supports
  are advertised; the model is forbidden from inventing concept ids,
  mixing languages, or exceeding the activity cap.
- `buildPlannerUserPrompt`: the three §62 sections — LANGUAGE
  KNOWLEDGE (the trusted concept menu with per-concept mastery status,
  the ONLY source of usable ids), LEARNER STATE (the M1 structured
  digest as JSON), TASK (session budget in minutes, repair-before-new
  ordering).
- `extractPlanJson`: string-aware, balanced-brace JSON extraction that
  tolerates markdown fences and surrounding prose without trusting
  them; malformed output degrades to `null` → a Left, never a crash.

### `spine/planner_output.dart` (pure Dart) — §14 validation boundary
- `AiPlanParser.parse`: untrusted model text → validated
  `LearningPlan` (`source: ai`). Accepts BOTH the full-plan shape and
  the Master Brief §14 single-decision shape (`nextConcept`).
- Per-step validation mirrors the runtime facade exactly: concept
  exists in the trusted graph, plan-level language gate, supported
  activity type (the brief's own example `"lesson"` correctly fails),
  difficulty 1..5 mapped onto the app's difficulty bands, lesson hint
  must equal the concept's trusted anchor, non-empty learner-facing
  reason. Invalid steps are DROPPED, never silently rewritten.
- Dedupe per (concept, kind); plan capped at `kMaxActivities` (8);
  `estimatedMinutes` clamped 1..30; missing focus summary gets an
  honest default line.

### `data/learn_plan_repository.dart` — the plan cache
- Key `learn_profile_<iso>_plan` inside the M2 `learn_profile_`
  namespace: the existing prefix-scoped reset covers it automatically.
- Same corruption contract as profile/diagnostic slots (missing /
  malformed / wrong-language → unset, never a crash). Legacy Sanskrit
  (`sa`) intentionally has no cache.
- `isFresh`: 7-day freshness window (§35 — cache stable planning
  outputs; learner-specific data stays local-only, one user per store).

### `data/gemini_planner.dart` — the AI planner + cached hop
- `PlannerTextClient`: the raw-text boundary (throw-based, trivially
  fake-able in tests). `GeminiPlannerTextClient`: production Gemini
  client — separate from the chat adapter on purpose (no persona
  pipeline, no prose moderation; the JSON contract is the safety
  boundary), 15 s timeout, conservative temperature, model reuse.
- `GeminiPlanner implements LearningPlanner`: never throws for expected
  failure modes — unconfigured key short-circuits BEFORE any network
  call; timeout → `TimeoutFailure`; any other failure → mapped Left.
  Accepted plans are cached write-through; a cache write failure can
  never fail a good plan.
- `CachedPlanPlanner implements LearningPlanner`: serves the last good
  AI plan relabelled `PlanSource.cached` (honest provenance, §63);
  missing / wrong-language / stale / empty caches are Lefts so the
  chain continues.

### `presentation/providers/learn_plan_providers.dart` — wiring
- `learnPlanRepositoryProvider`, `plannerTextClientProvider`,
  `geminiPlannerProvider`, `cachedPlanPlannerProvider`. The text client
  SHARES the chat adapter's `aiRateLimiterProvider` instance — one
  app-wide 15 RPM Gemini budget (§36), planner included.

## 3. The one-line swap (kept its promise)

`spine_providers.dart` `learningPlannerProvider` now composes:

```dart
ValidatingPlanner(
  delegate: gemini,
  fallback: ValidatingPlanner(delegate: cached, fallback: deterministic),
);
```

Every consumer keeps reading `learningPlannerProvider` unchanged, and
`activeLearningPlanProvider` now exposes `LearningPlanLike.source`
(ai / cached / deterministic) so M6's UI can label plans honestly.

## 4. Cost + latency control (§61)

- No Gemini call unless a plan is actually requested AND a key is
  configured (offline = instant deterministic plan, zero cost).
- One planning call serves a whole session; the result is cached and
  re-used by the fallback chain for up to 7 days.
- The 15 s timeout keeps the worst case bounded; beyond it the chain
  serves instantly from cache or the deterministic planner.
- Deterministic local logic still owns XP, streaks, mastery, validation
  and navigation — Gemini plans CONTENT choices only (§61/§64).

## 5. Tests (6 new files; run `flutter test` on a dev machine)

- `planner_prompt_test.dart` — schema strictness, kind menu reflects
  build capabilities, §62 section separation, trusted concept menu with
  statuses, digest embedding, budget statement, JSON extractor matrix
  (fences, prose, braces-in-strings, malformed, arrays).
- `planner_output_test.dart` — full-plan + §14 single-decision shapes,
  difficulty band mapping, every §14 drop rule, dedupe, cap, language
  gate, empty/all-invalid → Left.
- `learn_plan_repository_test.dart` — round-trip, per-language
  isolation, corruption safety, wrong-language rejection, Sanskrit
  no-op, M2 prefix reset coverage, freshness policy.
- `gemini_planner_test.dart` — unavailable = zero network calls,
  success + write-through cache, §62 prompt pair, timeout/garbage →
  typed Lefts, disk-full cache never fails a plan.
- `cached_plan_planner_test.dart` — honest cached provenance, all Left
  cases (empty / wrong language / stale / empty plan / Sanskrit).
- `planner_chain_test.dart` — the REAL provider wiring walked hop by
  hop: ai → cached → deterministic, stale-cache skip, garbage→cache,
  plus the facade id pinning the exact chain.

## 6. Preservation

Byte-level diff vs the M3 ZIP: 11 files added, 0 removed, 2 modified
(`spine.dart` barrel, `spine_providers.dart` wiring) + this doc and the
CHANGELOG entry. Every A–G content module, Exam Mode, VAN, AI chat, XP,
achievements, streaks and the signing mechanism are untouched; the
pre-M4 behaviour (deterministic plan) is preserved verbatim whenever AI
is unavailable.
