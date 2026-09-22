# VaaniX Production Audit — 2026-09-20

## Scope and method

This is a forensic baseline of the checked-out repository before production
hardening. It is based on the executable application paths, provider wiring,
repository implementations, assets, platform projects, automated tests, and
static scans. A component is not described as complete merely because a type,
provider, or test exists.

The worktree was clean at the start (`main...origin/main`). No user changes
were reset or discarded.

## Baseline

| Item | Evidence |
| --- | --- |
| Flutter / Dart | Flutter 3.47.4 stable; Dart 3.13.3 |
| Package surface | 12 runtime packages, including Riverpod, GoRouter, Supabase, Sentry, Gemini, SharedPreferences, Lottie, and Connectivity Plus |
| Repository size | 284 Dart files under `lib/`; 140 Dart test files; 626 non-generated tracked/discovered files |
| Assets | 35 asset files: 20 JSON curriculum/metadata files, 5 fonts, 9 PNGs, 1 license; no `.mp3`, `.wav`, or Lottie animation JSON assets |
| Backend inventory | No FastAPI service, OpenAPI schema, Docker configuration, Supabase CLI configuration, migration, or SQL schema file exists. `docs/Build/Supabase.md` and `docs/Build/FastAPI.md` are empty. |
| Environment | `.env.example` declares `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE_URL`, Sentry DSN, and Gemini key. `assets/env/.env` is intentionally absent in this checkout. |
| Platform baseline | Android has application ID `com.vaanix.app`, min SDK 24, target/compile SDK 36, and a release-signing guard. iOS project and camera/photo permissions exist. No Windows runner exists, so Windows cannot be built from this project. |
| Static analysis | `flutter analyze` exits non-zero with 339 lint diagnostics: 1 warning and 338 infos in the captured run; no compile error was reported. |
| Test baseline | `flutter test --reporter compact`: 1,606 tests executed in 3m46s; 7 failures. The failed names are recorded below. |

## Dependency map

```text
main.dart
  -> loadEnvironment()
  -> SentryFlutter.init / guarded zone
  -> bootstrap()
       -> optional Supabase.initialize
       -> SharedPreferences.getInstance
  -> ProviderScope overrides
       -> sharedPreferencesProvider
       -> coreAuthRepositoryProvider -> authRepositoryProvider
  -> VaaniXApp
       -> appRouterProvider / GoRouter
       -> SessionManager / lifecycle / analytics

UI -> Riverpod feature provider -> domain contract / engine
   -> SharedPreferences-backed repository (nearly all durable app state)

Supabase -> initialization + authentication only
Gemini -> direct Flutter SDK calls for chat, Learn planner/content, Exam planner,
          and image evaluation
FastAPI -> environment constant only; no application client or server
```

### Bootstrap and dependency injection findings

`sharedPreferencesProvider` and `coreAuthRepositoryProvider` deliberately throw
when not overridden. The normal `main.dart` startup path supplies both before
mounting `VaaniXApp`; those guards are valid and must remain.

`bootstrap()` deliberately keeps the app offline-capable when there is no
environment file. A fatal SharedPreferences failure renders a retryable
bootstrap failure app.

**P0 — configured Supabase initialization failures are swallowed.**
`_initializeSupabase()` logs and returns after an initialization error. The
environment remains marked configured, so `authRepositoryProvider` selects
`SupabaseAuthRepository`, which reads `Supabase.instance.client` even though
initialization failed. This is a broken legitimate startup path. The bootstrap
contract must surface a retryable backend-initialization state or reliably
fall back to the no-op repository; it must never select an uninitialized
client.

### Routing findings

The router has a splash route, onboarding gate, configuration-aware auth gate,
stateful home/Learn/Exam shell, nested Learn and Exam flows, auxiliary routes,
and a branded not-found path. Unit tests cover the pure guard and not-found
behavior. Offline/no-backend mode intentionally does not auth-gate the user.

The authenticated route gate is structurally sound for its current local-only
mode, but it cannot guarantee cloud data isolation because durable feature
repositories do not depend on the authenticated user.

## Feature matrix

| Feature | UI | Domain/data | Persistence | Network | Tests | Production status |
| --- | --- | --- | --- | --- | --- | --- |
| Onboarding | Yes | Yes | Local | None | Yes | Partially implemented: not user-scoped/cloud synced |
| Home | Yes | Provider-driven | Local-derived | None | Yes | Partially implemented |
| Learn adaptive spine | Yes | Diagnostic, graph, planner, session, mastery | Local JSON/preferences | Direct Gemini optional | Extensive | Partially implemented: adaptive local flow exists; no cloud persistence/sync |
| Learn generated content | Yes | Parser/validator/trusted boundary | Local cache | Direct Gemini optional | Yes | Partially implemented: client key model is not production-safe |
| Exam | Yes | Scope, diagnostic, planner, practice, PYQ/mock, weak area | Local JSON/preferences | Direct Gemini optional | Extensive | Partially implemented: no user/cloud boundary; mock deterministic test is invalid as written |
| Auth | Yes | Supabase and no-op implementations | SDK session | Supabase Auth | Yes | Implemented but externally dependent; initialization failure path is unsafe |
| Profile/progress/achievements | Yes | Local repositories | Local | None | Yes | Partially implemented: device-global state is exposed across account changes |
| Settings | Yes | Theme/preferences | Local | None | Targeted | Partially implemented |
| AI chat | Yes | Service, adapters, memory, safety, rate limiting | Local transcript/cache/usage | Direct Gemini | Yes | Partially implemented; client-side privileged key limitation |
| VAN | Yes | Event/reaction/controller/renderer | Metadata only | None | Yes | Partially implemented: native fallback works; real Lottie files absent |
| Audio | Decorative taxonomy/widget only | Event enum only | None | None | No service coverage | Not implemented |
| Syllabus | Yes | Asset loader/index | Bundled JSON | None | Yes | Implemented as bundled trusted data; completeness/provenance remains an editorial responsibility |

## Data, backend, and sync audit

Supabase is currently used by authentication only. There are no PostgREST
queries outside the auth feature, despite `supabaseDatabaseProvider` being
declared. The `API_BASE_URL` value has no client, endpoint invocation, or
backend implementation. It is dead production configuration.

Durable state is stored in plain SharedPreferences under global keys and JSON
blobs. Examples include profile, XP/completions/quiz attempts, Learn language,
learner profiles, plans, generated content, AI transcripts/cache/token usage,
exam profiles/scopes/plans/attempts/PYQ/mock outcomes, weak areas, and
achievement/daily activity state.

**P0 — no database schema or RLS exists.** No migration can establish
ownership, foreign keys, indexes, deletion behavior, or row-level policies.

**P0 — no sync contract exists.** There is no local outbox, remote version,
idempotency key, conflict rule, retry scheduler, first-login migration,
logout/account-switch boundary, or remote deletion semantic. `SessionManager`
claims local state is cleared on sign-out but does not perform that operation.
Consequently, a second account on one device can read the first account's
local learning state.

### Phase 1 schema mapping

`supabase/migrations/202609200001_initial_user_data.sql` is the first
versioned schema artifact. It does not invent curriculum or test data. It maps
the currently serialized repositories to user-owned aggregates as follows:

| Supabase table | Existing Flutter owner |
| --- | --- |
| `profiles`, `app_preferences`, `streak_states` | `LocalUserProfileRepository`, `LocalStorageService`, theme/settings providers |
| `learner_profiles`, `learning_states`, `learning_plans` | `LearnProfileRepository`, spine/plan providers |
| `generated_content` | `GeneratedContentRepository`, personalized-content cache |
| `progress_states`, `quiz_attempts` | `LocalProgressRepository` |
| `achievements`, `daily_activity` | `AchievementRepository`, `DailyActivityRepository`, milestone repositories |
| `ai_conversations`, `ai_usage_records` | `LocalConversationMemory`, `TokenUsageTracker` |
| `exam_scopes`, `exam_profiles`, `exam_learner_profiles`, `exam_plans` | corresponding Exam repositories |
| `exam_attempts`, `exam_weak_areas`, `pyq_performance`, `mock_results`, `exam_hub_states` | Exam attempt, weak-area, PYQ/mock, and hub repositories |

Each record uses `auth.users.id` as its owner, cascades on user deletion, and
has server-managed `updated_at` / optimistic `revision` fields. RLS enables
only own-row select/insert/update/delete operations. The migration is static
reviewed in this checkout; applying it and exercising the policies requires a
real Supabase project and is therefore an external Phase 1 gate.

### Recommended minimum coherent production architecture

1. **Supabase Auth** owns identity and session refresh only.
2. **Supabase Postgres** owns user-owned state. Start with an explicit,
   versioned migration and RLS for every user row. Retain SharedPreferences as
   the offline cache; do not replace it with immediate network calls.
3. **A dedicated sync layer** owns local mutation capture, idempotent upload,
   pull/merge, retry, account switching, and deletion. Repositories continue
   to expose their existing domain contracts and are migrated one aggregate at
   a time behind that layer.
4. **A server-side API is required for privileged AI** (Gemini proxy,
   validation, rate limits, observability). Until it is deployed, do not place
   a privileged Gemini key in a shippable Flutter environment asset and do
   not describe client-side Gemini as production-ready.

This is the smallest division that matches the present code without rewriting
the Riverpod/domain/data architecture.

## AI, VAN, audio, observability, security, and release findings

* Gemini SDK types are confined to data adapters rather than UI, and Learn
  generated content has a validated `gen-` boundary. However, multiple direct
  client-side Gemini paths exist (chat, Learn planner/content, Exam planner,
  vision evaluation). A bundled key can be extracted; server-side mediation is
  required for production.
* The app has offline tutor and deterministic planner fallback paths. They
  preserve local learning operation but are not cloud-sync behavior.
* VAN has an event/controller architecture and Flutter-native visual fallback.
  `lottie` is a dependency and constants refer to Lottie paths, but asset
  inventory confirms none of those animation files exists. It must be reported
  as fallback-motion MVP, not Lottie-complete.
* Audio consists of `VaanixAudioEvent` and a waveform control. There is no
  resolver, playback package/service, policy, or audio asset inventory.
* Sentry bootstrapping and a central logger exist. Eleven data repositories
  still call `debugPrint` for corrupt-state failures; they should be routed
  through privacy-reviewed structured logging in the observability phase.
* The tracked source scan found no committed service-role key or real Gemini
  key. `.gitignore` excludes `.env`, `key.properties`, and keystores. This does
  not make shipping a real `assets/env/.env` safe: any Gemini key included
  there is still client-readable.
* Android release signing correctly fails closed when signing material is
  unavailable. Release artifact validation cannot pass without external
  signing credentials. iOS compilation is not available on this Windows host.

## Baseline test failures — must be resolved before later gates

| Test | Evidence-based cause / next action |
| --- | --- |
| `mock_engine_test.dart`: deterministic same attempts → identical result | `MockEngine.analyze()` defaults `completedAtIso` to `DateTime.now()`, while the test compares `toJson()` twice. The analysis itself is deterministic; the test is invalid unless it injects a fixed `now`, or completion-time semantics are moved outside the deterministic result contract. |
| `diagnostic_screen_test.dart`: full happy path; feedback beat | Widget tests use long fake-clock polling around asset/provider loading. Reproduce after the test’s own prewarm phase to determine whether the failure is lifecycle/settling or UI logic; do not increase its budget. |
| `session_screen_test.dart`: correct run | Same category: isolate UI/provider lifecycle with existing fake-clock controls. |
| `smart_practice_screen_test.dart`: trusted ready view; personalization; offline handling | Same category: asset/provider/controller settling failure must be located before changing production behavior. |

The complete baseline test run did not hang. It completed in 3m46s with 1,606
tests and 7 failures, so timeout inflation is not an appropriate remedy.

## Dependency-aware execution order

1. Fix the isolated deterministic test contract and the confirmed bootstrap
   initialization defect; rerun their targeted tests.
2. Create actual Supabase migrations, ownership model, RLS policies, and a
   testable local-to-cloud sync contract. Do not claim the phase gate until a
   real Supabase project can apply and exercise the migrations.
3. Migrate one user-state aggregate at a time behind existing repository
   contracts, beginning with profile/preferences and Learn state, and implement
   account-switch isolation before expanding cloud coverage.
4. Remove dead API configuration or implement a typed backend client only when
   a deployed backend contract exists; move privileged AI calls server-side.
5. Resume Learn, Exam, UI, VAN, audio, observability, security, performance,
   suite, formatting, and build phases in that order.

## Phase 0 gate

**Status: complete.** The repository was inspected before modification, the
baseline was recorded, actual execution paths were traced, and the first
dependency blockers are documented. Phase 1 is **not passed**: it requires a
real Supabase project/credentials to execute migrations and RLS tests, plus
implementation of the sync/account boundary.

## Phase 1 progress (in progress)

### Problem 1.1 — configured Supabase could continue uninitialized

* **Root cause:** `_initializeSupabase()` caught and logged a configured
  initialization failure, then allowed dependency injection to select the
  Supabase auth repository.
* **Fix:** `bootstrap()` now propagates configured initialization failures to
  `main.dart`'s existing retryable bootstrap failure screen. Its optional
  initializer seam exists solely to test that behavior without a real project.
* **Regression test:** `bootstrap_supabase_failure_test.dart` asserts that a
  configured initialization failure aborts bootstrap. The focused Flutter test
  command was started alongside the existing offline bootstrap test; this host
  session did not return a terminal result despite no remaining Flutter/Dart
  process, so it is recorded as **inconclusive**, not passed.

### Problem 1.2 — cloud schema and RLS were absent

* **Root cause:** there was no Supabase migration or database implementation.
* **Fix:** added `supabase/migrations/202609200001_initial_user_data.sql`.
  It creates the mapped user-owned aggregates, ownership FKs, cascades,
  primary/secondary indexes, revision/timestamp trigger, and explicit RLS
  policies.
* **Verification:** `git diff --check` passes. SQL application and live
  cross-user RLS verification are **externally blocked** because this checkout
  has neither the Supabase CLI/`psql` nor a Supabase project URL/anon key.

**Phase 1 gate: not passed.** The remaining required work is the actual
local-to-cloud sync engine, safe migration of local keys, account-switch
isolation, and live migration/RLS verification against a user-provided
Supabase project.
