# VaaniX Learn Mode 2.0 — Milestone 0 Forensic Audit

Date: 2026-09-10
Scope: full inspection of the uploaded project ZIP (`VaaniX-Learn-Part-G-Urdu.zip`,
root folder `VaaniX-Core-FINAL`). **No source code was modified during this
audit** (per Milestone 0 rules). This document is the only file added, and it
lives under `docs/Audits/` alongside its predecessor `V1-Learn-Part0-Audit.md`.

Validation constraint: Flutter/Dart SDK was not available in the audit
sandbox. All findings below are from static source inspection and direct
asset parsing (the curriculum JSON files were parsed programmatically).
Test-suite execution remains a user-machine step (same note as the Part E–G
changelog entries).

---

## 1. CURRENT ARCHITECTURE

### 1.1 Project identity

| Item | Value |
|---|---|
| Package name | `vaanix_app` (pubspec.yaml) |
| Version | 1.0.0+1 |
| Application ID | `com.vaanix.app` |
| Dart SDK constraint | `>=3.6.0 <4.0.0` (Color.withValues + Material 3 theme APIs) |
| Verified toolchain | Flutter ≥ 3.32, verified on 3.47.2 stable (README) |
| State management | flutter_riverpod 2.5.x (hand-written providers, no codegen) |
| Navigation | go_router 14.2.x, StatefulShellRoute.indexedStack, 5-tab bottom nav |
| Backend | supabase_flutter 2.5.x (optional — app is fully usable offline) |
| AI SDK | google_generative_ai 0.4.6 (Gemini, model default `gemini-2.5-flash`) |
| Crash reporting | sentry_flutter 9.x |
| Storage | shared_preferences via ILocalStorageService abstraction |
| Fonts | Poppins 400–800 bundled (OFL) |
| Error strategy | Exceptions → ExceptionMapper → Failure → Either<Failure, T> (dartz) |

### 1.2 Layer map (verified against source)

```
lib/
├── app/            bootstrap (env→Supabase→prefs), GoRouter + guards, splash
├── core/           auth contract, constants, environment, errors, lifecycle,
│                   logging, navigation, providers, storage, supabase, theme, utils
│                   + core/analytics/ (AnalyticsClient, AnalyticsEvent —
│                   NoopAnalyticsClient default; exercise events instrumented)
├── features/
│   ├── learn/          domain: learn_language.dart (catalogue), exercise_models.dart
│   │                   data: curriculum_loader.dart, learn_language_repository.dart,
│   │                       sanskrit_curriculum/lesson_content/unit2_lesson_content,
│   │                       {sanskrit,hindi,bengali,marathi,telugu,tamil,
│   │                          gujarati,urdu}_exercises.dart  (8 banks)
│   │                   presentation: learn_screen, learn_language_selection_screen,
│   │                       lesson_content_screen, exercise_screen (1,070 LOC),
│   │                       providers (exercise_providers, learn_language_providers)
│   ├── progress/       domain: progress_models, progress_repository, adaptive.dart,
│   │                   gamification.dart; data/local_progress_repository.dart;
│   │                   presentation: progress_screen, progress_providers,
│   │                   adaptive_providers
│   ├── achievements/   10 definitions, checker, repository, screen
│   ├── exam/           quiz_providers + exam_screen (separate product track)
│   ├── home/           home_screen (553 LOC) — VAN hero + adaptive CTA
│   ├── ai/             full chat stack (see §5)
│   ├── profile/        UserProfile (name, companion, personality, CBSE class,
│   │                   dailyGoalMinutes, streak, lastActiveDate) + local repo
│   ├── onboarding/     6 pages (name → goal → class → personality → auth → nest)
│   ├── settings/       theme, AI reset, profile reset
│   └── van/            domain (state/event/reaction), controller, asset catalog
│                       (8 expressions, parity-tested), visual renderer
└── shared/         20+ reusable widgets (cards, badges, empty/error states,
                    offline banner, van speech strip, XP/streak badges)
```

Dependency rule is respected in source: `core` never imports `features`;
`features → core, shared` only. Analysis options enforce lints
(flutter_lints 3 + riverpod_lint).

### 1.3 Navigation routes (verified)

`/splash`, `/onboarding`, `/auth`; shell tabs: `/home`, `/learn`
(+ `/learn/language`, `/learn/lesson/:lessonId`, `/learn/lesson/:lessonId/practice`),
`/exam`, `/progress`, `/van-profile`; plus `/settings`, `/chat`, `/achievements`.
Redirect guards: onboarding gate → auth gate (when Supabase configured).

---

## 2. CURRENT LEARN MODE CAPABILITIES

| Capability | State | Evidence |
|---|---|---|
| Language picker | ✅ 10-language locked catalogue, script/direction badges, RTL-aware native-name rendering | `learn_language.dart`, `learn_language_selection_screen.dart` |
| Per-language curriculum load | ✅ JSON assets, schema-version guard (refuses >1), error-tolerant (empty, never crash) | `curriculum_loader.dart` (`loadLearnCurriculum`) |
| Active-curriculum dispatch | ✅ selected language → per-language provider; null → legacy Sanskrit fallback | `activeCurriculumProvider` |
| Lesson rendering | ✅ mini-markdown (H1, paragraphs, bullets, tips, 3-col tables), Devanagari-styled spans | `lesson_content_view.dart` |
| Exercise engine | ✅ 5 types (mcq, fillBlank, ordering, translation w/ normalized accepted answers, matching); deterministic option shuffling; first-try-only scoring; retry-after-wrong; resume (persisted snapshot, drift-safe restore); empty-state safe | `exercise_providers.dart`, `exercise_screen.dart` |
| Exercise dispatch | ✅ by lesson-ID prefix across 8 banks (`exercisesByLesson` → `hi_` → `bn_` → … → `ur_`) | `exercise_providers.dart` |
| Exercise analytics | ✅ `exerciseCompleted` events with exerciseId/correct/firstTry | `ExerciseNotifier.submit()` |
| Progress persistence | ✅ completed lessons (idempotent XP), completed quizzes, per-quiz attempt history (cap 20, best always retained), per-lesson mastered-exercise sets, bonus-XP ledger, full prefix-based reset | `local_progress_repository.dart` |
| XP / levels | ✅ deterministic curve: level N needs 100·N XP; badges read same source | `gamification.dart` |
| Streak | ✅ currentStreak + lastActiveDate on UserProfile (day-granularity) | `user_profile.dart` + repo |
| Achievements | ✅ 10 learning-linked achievements, threshold checker, XP bonus via ledger | `achievement_definitions.dart` |
| VAN integration | ✅ VanWidget on Home (hero) + speech strip; event/reaction controller; 8 expression assets with catalog parity test | `van/`, `home_screen.dart` |
| RTL support | ✅ catalogue metadata + Directionality applied on selection card and Learn screen chapter tiles | grep `isRTL` |
| Offline | ✅ full local stack; offline banner; AI chat falls to OfflineModelAdapter/OfflineTutor | multiple |

### 2.1 Adaptive behavior — what exists today

`progress/domain/adaptive.dart` computes a single deterministic `NextAction`
from REAL persisted state with a fixed priority ladder:

1. `allDone` — everything complete + every chapter exam passed
2. `takeChapterExam` — first chapter whose lessons are done but exam < 60%
3. `practiceWeakTopic` — earliest completed lesson with unmastered exercises
4. `continueLesson` / `startJourney` — next unfinished lesson in order

This engine is genuinely grounded (no randomness, unit-tested) but it is:
- **linear** — it walks the fixed curriculum order; there is no concept graph,
  no difficulty adaptation, no skipping, no prerequisites;
- **legacy-curriculum-wired** — `adaptive_providers.dart` reads
  `curriculumProvider` (Sanskrit v1.json) and `exercisesByLesson`
  (Sanskrit bank) only. The Home adaptive CTA therefore does NOT yet react
  to the selected Learn Mode language;
- **not AI-assisted** — no model involvement in planning.

---

## 3. CURRENT STATIC CURRICULUM STATE (verified by parsing every asset)

| Language | File | Bytes | schema | Chapters | Lessons | Difficulty mix | Exercise bank | ID prefix |
|---|---|---|---|---|---|---|---|---|
| Hindi | hi.json | 99,650 | 1 | 5 | 20 | 11 beg / 6 int / 3 adv | 69 | `hi_` |
| Bengali | bn.json | 113,538 | 1 | 5 | 20 | 11 / 6 / 3 | 66 | `bn_` |
| Marathi | mr.json | 102,061 | 1 | 5 | 20 | 11 / 6 / 3 | 68 | `mr_` |
| Telugu | te.json | 103,485 | 1 | 5 | 20 | 11 / 6 / 3 | 64 | `te_` |
| Tamil | ta.json | 116,365 | 1 | 5 | 20 | 11 / 6 / 3 | 61 | `ta_` |
| Gujarati | gu.json | 57,081 | 1 | 5 | 20 | 11 / 6 / 3 | 59 | `gu_` |
| Urdu | ur.json | 79,297 | 1 | 5 | 20 | 12 / 5 / 3 | 66 | `ur_` |
| Kannada | kn.json | 502 | 1 | 0 | 0 | — | none | — |
| Malayalam | ml.json | 511 | 1 | 0 | 0 | — | none | — |
| Odia | or.json | 493 | 1 | 0 | 0 | — | none | — |

- All populated files: unique lesson IDs, `language` metadata block matching
  the catalogue (verified by per-language tests, e.g. `urdu_curriculum_test.dart`
  asserts enum/iso/script/direction incl. `rtl`).
- Legacy Sanskrit track (Exam Mode): `assets/curriculum/v1.json` — 4 chapters,
  4 quiz groups, 32 questions + Dart fallback (`sanskrit_curriculum.dart`).
- Total Learn exercise bank: 453 exercises across 7 languages (+52 Sanskrit).
- MATCHES THE BRIEF'S EXPECTED STATE EXACTLY (A–G live, H–J stubs).

Note (doc hygiene, non-blocking): CHANGELOG.md contains a duplicated
"Part F — Gujarati" entry (two identical sections); harmless, fix opportunistically.

---

## 4. LANGUAGE SYSTEM

- Catalogue: `kLearnLanguageCatalogue` — locked, ordered, 10 entries; fields:
  enum, ISO 639-1/2 codes, English + native names, script name + ISO 15924
  code, direction, asset path. Urdu `Arab`/RTL is the only RTL entry; no RTL
  leakage into others (Directionality applied per-spec at widget level only).
- Persistence: `LearnLanguageRepository` on storage key `learn_language`;
  corrupt values degrade to "no selection" (never crash).
- Loading: schema guard + try/catch → empty list on malformed/missing asset
  (Learn screen shows "coming soon", picker stays alive).
- Dispatch: `activeCurriculumProvider` (curriculum) and lesson-ID-prefix
  chain (exercises). Both are contract-stable for adding H–J content.
- GAP: curriculum JSON has no concept/prerequisite graph — chapters/lessons
  only. There is no skill dimension, no concept IDs, no mastery criteria,
  no difficulty metadata beyond the single `Difficulty` enum on lessons.

---

## 5. CURRENT AI CAPABILITIES

Chat stack (VAN) — mature and well-tested (9 dedicated test files):

- `ModelAdapter` abstraction (`ai/domain/model_adapter.dart`) — provider
  replaceable by design; two implementations:
  `GeminiModelAdapter` (google_generative_ai SDK) and `OfflineModelAdapter`
  (+ rule-based `OfflineTutor`).
- Gemini adapter: input sanitized by SafetyFilter, output moderated;
  defensive system prompt prepended; 30 s timeout; 2 retries with bounded
  backoff for transient errors only; permanent failures mapped to typed
  Failures (AiRateLimitFailure, AiContentFilterFailure, AiContextLengthFailure,
  TimeoutFailure, AiServiceFailure).
- AiRateLimiter (15 RPM), ResponseCache, TokenUsageTracker (daily usage).
- ConversationPipeline: bounded transcript (100 messages), local memory
  (5 conversations), learning-context stamped per turn.
- LearningContext: bounded (≤3 weak titles, ≤60 chars each, ≤900-char
  fragment), grounded (real repository data only), injected into persona
  so VAN personalizes around real progress.

**AI + Learn Mode — the decisive gap:** there is NO AI planner. The model is
used for chat only. Nothing consumes a structured `LearningPlan`; nothing
validates AI JSON against the curriculum; no placement/diagnostic flow exists.

Also noted: `DefaultSafetyFilter.defensiveSystemPrompt()` hardcodes
"Never provide content unrelated to **Sanskrit** language learning" — must be
generalized per-language (or per-topic) for Learn Mode 2.0, otherwise the
defensive prompt actively fights 9 of the 10 Learn languages.

---

## 6. CURRENT ADAPTIVE CAPABILITIES (summary)

Exists: deterministic 4-rule next-action engine; weak-lesson detection;
per-lesson exercise mastery (binary sets); chapter-exam gating at 60%;
chapter-best display state (attempted-vs-not distinction fixed in Phase 2).

Missing for Learn Mode 2.0: per-language wiring (§2.1), concept-level
mastery model (introduced → practiced → recalled → applied → mastered →
maintained), spaced review queue, difficulty adaptation, prerequisite
repair, skipping, placement test, AI planner + validation + fallback chain.

---

## 7. CURRENT GAMIFICATION CAPABILITIES

XP (lesson rewards + 10/correct-answer + idempotent bonus ledger), level
curve, streak (day-granularity on profile), 10 achievements, progress
screen (journey %, chapter bests, weak areas), VAN reactions. Gaps: no
daily-goal tracking loop (goal minutes stored but not measured against
activity), no milestones-as-competency system, no challenge/review rewards,
streak is global not per-language (acceptable; matches cross-language UX).

---

## 8. EXAM MODE / VAN SEPARATION (verified)

- Exam Mode reads only `curriculumProvider`/`loadAllQuizQuestions`
  (v1.json + Dart fallback) and the `quiz_<chapter>_<difficulty>` space.
  Learn Mode reads `learnCurriculumProvider(language)` and ID-prefixed
  exercise banks. No logic merge; sharing is limited to the Chapter/Lesson/
  QuizQuestion models and storage service — by design.
- Exam content grounding test (`exam_content_grounding_test.dart`) keeps
  exam questions tied to the curriculum; `quiz_bank_single_source_test.dart`
  pins the single-source rule.
- VAN: mounted via `vanControllerProvider` + VanWidget on Home; expressions
  parity-tested against `assets/van/metadata/van_assets.json` (8 expressions,
  PNG source of truth untouched). Learn screens currently use VAN dialogue
  strings from the adaptive engine; no VAN artwork changes anywhere.

---

## 9. TESTS INVENTORY (70 files, static review)

- AI (9): safety filter, offline tutor, controller race, adapter guards,
  transcript caps, request shaping, VAN speaking, learning context, streaming.
- Learn (19): engine, types, screen, resume, empty state, navigation,
  catalogue, repository, selection screen, curriculum + expansion (Sanskrit),
  dispatch (learn + active), per-language curriculum tests ×7 (hi bn mr te ta gu ur).
- Progress (12): adaptive next action, adaptive providers, weak areas (×2),
  gamification, idempotency, rollback, reset purge, attempts cap, chapter
  best, bonus XP ledger, persistence lifecycle.
- Exam (5), VAN (4), accessibility (4), profile (3), environment (2),
  core (2), router (2), onboarding (1), achievements (1), home (1),
  settings (1), platform assets (1), widget smoke (1).
- Tests read real assets from disk (e.g. Urdu test loads ur.json directly) —
  they will run wherever `flutter test` runs with the repo checked out.
- No test exercises kn/ml/or (correctly — nothing to assert beyond stubs;
  catalogue test covers their metadata).

---

## 10. PLATFORM / SECURITY / RELEASE

- Android: `com.vaanix.app`, minSdk 24, targetSdk 36. Release signing driven
  by `android/key.properties` (gitignored) with strict guards — release
  builds NEVER fall back to the debug key (`key.properties.example` provided).
  `key.properties` is NOT present in the ZIP (correct — secrets stay out).
- iOS: standard Runner project present. Web: present (favicon/manifest/icons).
- Env: `assets/env/` bundled via pubspec (dotenv for Supabase/Gemini/Sentry);
  no API keys committed (verified: only `*.example` files).
- `pubspec.lock` committed (reproducible builds). `analysis_options.yaml`
  present with lints. Archive/ folder (Code 1.0–4.0) is historical dead
  weight but PRESERVED per the no-deletion rule; it is excluded from
  compilation (outside lib/, no test imports it).

---

## 11. CURRENT GAPS → LEARN MODE 2.0 TRANSFORMATION MAP

| # | Gap (observed) | Brief target | Milestone |
|---|---|---|---|
| G1 | No learner profile for learning (level, goal, desired level, pace, per-language state) | LearnerProfile + goal system | M2 |
| G2 | No placement/diagnostic; no level estimation | Adaptive 3–7 min diagnostic, multi-dimension, structured result | M3 |
| G3 | No AI planner; chat-only AI | Gemini planner, structured LearningPlan, validated concept refs | M4 |
| G4 | Curriculum is lesson lists only — no concept/skill graph, no prerequisites | Language → Skill → Concept → Content → Exercise → Mastery → Milestone | M1/M5 |
| G5 | Static content is the path (fixed 20-lesson walk) | Content = trusted seed pool; planner may skip/review/reorder | M5 |
| G6 | Mastery = per-lesson exercise sets (binary) | Concept mastery lifecycle + review/forgetting handling | M6 |
| G7 | Adaptive engine wired to legacy Sanskrit curriculum only | Wire adaptive inputs to active Learn language | M1 (fix first) |
| G8 | Exercise engine has no notion of new/practice/review/weak-repair/mastery-check/challenge sessions | Session-aware adaptive exercise engine | M6 |
| G9 | Gamification: no competency milestones, no daily-goal loop | Milestones represent competency; configurable criteria | M7 |
| G10 | Home CTA is Sanskrit-path driven; no "what should I do today" per language | Personal path / today's activity from learner state + planner | M8 |
| G11 | No language knowledge layer (grammar/vocab/errors/culture) for AI grounding | Per-language knowledge base; AI generates only from trusted layer | M9 |
| G12 | Defensive AI prompt hardcodes Sanskrit | Per-language/topic-aware safety + planner output validation | M4/M10 |
| G13 | Per-language XP/progress isolation absent (global XP pool) | Per-language learner state (planned in Parts A–K but never built) | M2 |
| G14 | No test coverage for adaptive/AI planning flows (they don't exist yet) | Full test matrix incl. failure modes (invalid JSON, unknown concept, rate limit, timeout) | M10/M11 |

## 12. RECOMMENDED TRANSFORMATION (order preserved from the brief)

1. **M1 — Architecture foundation:** introduce the Learn Mode 2.0 domain
   spine (LearnerProfile → Diagnostic → LearningState → Planner → Session →
   ExerciseEngine → Evaluation → Mastery → Replan) as NEW modules beside the
   existing ones; re-wire `adaptiveNextActionProvider`/weak-areas to the
   ACTIVE curriculum (G7) without touching Exam Mode; keep ModelAdapter
   abstraction as the AI boundary (provider stays swappable).
2. **M2 — Learner profile + goals:** extend (not replace) UserProfile with a
   per-language LearningProfile (level, desired level, goal, mastery map,
   review queue, pace, session history); storage namespaced
   `learn_profile_<lang>_…`; no sensitive data.
3. **M3 — Adaptive placement:** new diagnostic flow (VAN-led, game-like),
   seeded from trusted curriculum items, difficulty strategy (correct ×2 →
   harder; wrong → prerequisite), multi-dimension structured result, friendly
   presentation, never exposes raw scores; repeatable.
4. **M4 — Gemini planner:** structured prompt assembly (pedagogy rules /
   language knowledge / learner state / task / output schema) through the
   existing ModelAdapter; typed LearningPlan/PlannerDecision; validate
   concept existence, language match, activity type, difficulty; fallback
   chain cached-plan → deterministic planner → trusted content; respect rate
   limiter + cache; never for security-sensitive decisions.
5. **M5 — Content generation:** classify existing curricula as trusted seeds;
   planner selects from them first; AI-generated exercises validated
   (structure, fields, answer, language script) with trusted fallback; never
   render malformed AI content.
6. **M6 — Adaptive exercise + mastery engine:** session kinds (new/practice/
   review/repair/mastery-check/challenge), concept mastery lifecycle,
   prerequisite repair ladder, lightweight review scheduling.
7. **M7 — Gamification:** competency milestones (configurable criteria),
   daily-goal loop tied to real learning actions, review rewards; no dark
   patterns.
8. **M8 — Personal path UI:** Learn home = current level, milestones,
   next activity, mastery view (matches existing VaaniX design language).
9. **M9 — Ten-language knowledge integration:** per-language knowledge
   profiles (script/pronunciation/grammar/vocab/errors/culture/progression)
   consumed by planner prompts; H–I–J content added progressively WITHOUT
   new per-language systems.
10. **M10/M11/M12 — QA:** cross-language invariants (script/direction/
    isolation), AI failure-mode matrix, end-to-end flows, performance
    (no AI calls on UI thread, caching), production freeze.

**Preservation guarantees honored during audit:** no source file modified;
all A–G curricula, Exam Mode, VAN, AI stack, XP/mastery/progress/streaks/
onboarding/auth/signing untouched. The M0 ZIP packages the complete,
unmodified project (plus this audit document).
