# V1 Learn Mode Part 0 Audit

**Date:** 2026-09-10
**Part:** 0 — Foundation + Architecture
**Starting state:** `VaaniX-Core-ProductionSigning.zip` (pre-Part-0 baseline)
**Ending state:** `VaaniX-Learn-Part-0-Foundation.zip`

## What this audit covers

Part 0 inspects the existing VaaniX project to determine what already
works, what can be reused, what must be extended, and where each Learn
Mode language's curriculum should live. It implements ONLY the
infrastructure needed to support the 10-language curriculum and preserves
all existing functionality.

## Existing architecture (pre-Part-0)

### Learn Mode (legacy — Sanskrit)

- **Curriculum source:** `assets/curriculum/v1.json` (single JSON asset
  shipped in the APK, declared in `pubspec.yaml` under `assets/curriculum/`).
- **Loader:** `loadCurriculum()` in `lib/features/learn/data/curriculum_loader.dart`
  reads the JSON, parses `chapters` into `Chapter` / `Lesson` (defined in
  `lib/features/progress/domain/progress_models.dart`), and merges in
  lesson content strings from `sanskrit_lesson_content.dart` +
  `unit2_lesson_content.dart`. Falls back to the hardcoded
  `sanskritCurriculum` Dart constant on any JSON parse error.
- **Provider:** `curriculumProvider` — `AsyncNotifierProvider<CurriculumNotifier,
  List<Chapter>>` with a `reload()` hook for invalidation.
- **Quiz bank:** `loadAllQuizQuestions()` flattens the `quizzes` array
  from the same JSON into one `List<QuizQuestion>`. Used by Exam Mode.
  Hardcoded fallback: `chapterQuizzes` (Map<String, List<QuizQuestion>>)
  in `sanskrit_curriculum.dart`.
- **Coverage:** 4 chapters, 13 lessons, 32 quiz questions (CBSE Ruchira
  Units 1–4, Section A). Tests in `curriculum_expansion_test.dart`
  enforce these numbers and JSON↔Dart parity.

### Exercise engine

- **Types:** MCQ, fill-in-the-blank, ordering, translation, matching
  (defined in `lib/features/learn/domain/exercise_models.dart`).
- **Bank:** `exercisesByLesson` — Map<String, List<Exercise>> in
  `sanskrit_exercises.dart`, keyed by lessonId.
- **Provider:** `exercisesForLessonProvider` (family by lessonId),
  `exerciseSessionProvider` (StateNotifierProvider.family by lessonId).
- **Mastery:** mastered exercise ids persisted per lesson via
  `LocalProgressRepository.recordMasteredExercises(lessonId, ids)`.
  Reactive through `masteredExercisesProvider` (family by lessonId).

### Progress / mastery / XP

- **Repository:** `LocalProgressRepository` over `SharedPreferences`.
  Persists: completed lesson ids, completed quiz ids, quiz attempt
  history (JSON-encoded), mastered exercises per lesson, XP total,
  streak, last-active date.
- **Providers:** `completedLessonIdsProvider`, `completedQuizIdsProvider`,
  `xpTotalProvider`, `masteredExercisesProvider`, `recordMasteryProvider`.
- **Adaptive:** `adaptive_providers.dart` reads mastery + quiz history
  to surface weak areas and next-action recommendations on Home /
  Progress screens.

### Exam Mode

- **Screen:** `lib/features/exam/presentation/screens/exam_screen.dart`.
- **Provider:** `quizProviders.dart` consumes `loadAllQuizQuestions()`
  and the adaptive engine.
- **Tests:** `quiz_bank_single_source_test.dart` enforces single-source
  of truth (JSON, not hardcoded Dart, is the primary path).
- **Untouched by Part 0.**

### VAN (mascot)

- **Domain:** `lib/features/van/domain/` — `VanState`, `VanEvent`,
  `VanReaction`, `VanExpression`, `VanAssetCatalog`.
- **Presentation:** `VanWidget` (StatefulWidget), `VanController`
  (StateNotifier), `VanVisualRenderer`, `van_asset_catalog_loader.dart`.
- **Assets:** `assets/van/master/VAN_master.png` (reference, NOT bundled),
  `assets/van/expressions/*.png` (canonical, bundled),
  `assets/van/metadata/van_assets.json`.
- **Untouched by Part 0.**

### AI tutor

- **Domain:** `lib/features/ai/domain/` — `AiService`, `ModelAdapter`,
  `ConversationPipeline`, `PromptPipeline`, `ConversationMemory`,
  `LearningContext`, `AiConfig`, `AiMessage`.
- **Data:** Gemini adapter (online), offline tutor (offline fallback),
  conversation memory (SharedPreferences-backed, bounded retention),
  response cache, token usage tracker, rate limiter, safety filter.
- **Learning context:** `learning_context_provider.dart` reads curriculum
  state, mastery, recent mistakes, and feeds them to the model as a
  bounded snapshot per turn.
- **Untouched by Part 0.** The learning-context provider will be
  extended in later Parts to surface the selected Learn language.

### Routing

- **Router:** `go_router` with `StatefulShellRoute.indexedStack` for the
  main app shell (Home / Learn / Exam / Progress / Van). Pushed routes:
  Settings, Chat, Achievements.
- **Guards:** `guardRedirect` pure function — onboarding gate (every
  non-public route requires onboarding complete) + auth gate (protected
  routes require session when Supabase is configured).
- **Protected set:** Home, Learn (+ nested `/learn/lesson/:id` and
  `/learn/lesson/:id/practice`), Exam, Progress, VanProfile, Settings,
  Chat, Achievements.
- **Part 0 change:** added `/learn/language` nested under Learn (inherits
  the same protection).

### Storage

- **Backend:** `SharedPreferences` via `LocalStorageService`.
- **Keys (relevant):** `keyOnboardingComplete`, `keyOnboardingPage`,
  `keyUserCompanionName`, `keyPersonalityMode`, `keyDailyGoalMinutes`,
  `keyCurrentStreak`, `keyLastActiveDate`, `keySelectedClass`,
  `keyThemeMode`, `keyLanguage` (UI language), `keyXpTotal`,
  `keyCompletedLessonIds`, `keyCompletedQuizIds`, `keyLearnerName`.
- **Part 0 change:** added `keyLearnLanguage` (distinct from `keyLanguage`
  to avoid collision between UI language and Learn curriculum language).

### Production signing

- **Android:** `android/app/build.gradle.kts` declares the signing config
  driven by `key.properties` (template at `key.properties.example`).
  `android/local.properties` points at the local SDK.
- **Untouched by Part 0.**

## Decisions

### Where each language's curriculum lives

`assets/curriculum/learn/<code>.json` — one file per language, named by
ISO 639-1 code. Rationale:
- Independent authoring / review / versioning per language.
- No monolithic multi-megabyte JSON harming APK build or runtime parse.
- Loader can lazy-load only the selected language's asset.
- Future languages drop in without touching existing ones.

The legacy Sanskrit curriculum (`assets/curriculum/v1.json`) stays where
it is — it is Exam Mode content, NOT a Learn Mode language, and is
deliberately NOT moved under `learn/`.

### How 10 languages are represented cleanly

A single `LearnLanguage` enum (10 values, locked) + `LearnLanguageSpec`
value type holding all linguistic metadata. The catalogue is a single
`kLearnLanguageCatalogue` list — single source of truth for the picker,
the persistence layer, the AI context provider, and tests.

### How future languages could be added

Append to the enum + the catalogue list. The picker, repository, and
loader pick up the new entry automatically. The only manual step is
shipping the new `<code>.json` stub (Parts A–J fill content).

### How datasets are split

One JSON per language (see above). Inside each JSON: `levels`,
`chapters`, `quizzes`, `vocabulary` arrays. `chapters` reuses the
existing `Chapter` / `Lesson` domain models — no new schema for Part 0.

### How validation works

- **Schema version guard:** the loader refuses to load a JSON whose
  `schemaVersion` is newer than `kLearnCurriculumSchemaVersion`. Returns
  empty list (not error) so the picker stays alive.
- **Failure tolerance:** missing asset, malformed JSON, missing
  `chapters` array — all return empty list. The Learn screen shows
  "curriculum in development" instead of an error.
- **Test coverage:** `learn_curriculum_dispatch_test.dart` verifies
  every catalogue language's asset exists, parses, has schemaVersion 1,
  and returns empty in Part 0.

## What was reused

- `Chapter` / `Lesson` / `QuizQuestion` / `Difficulty` domain models
  (from `progress_models.dart`).
- `Chapter.fromJson` / `Lesson.fromJson` deserialization.
- `VaaniXScaffold`, `VanWidget`, `AppColors`, `AppTextStyles`,
  `AppDimens` widget / theme libraries.
- `ILocalStorageService` / `LocalStorageService` / `SharedPreferences`
  storage stack.
- `go_router` route structure + guard matrix.
- Riverpod 2.x `AsyncNotifierProvider` + `.family` patterns.
- Test infrastructure: `SharedPreferences.setMockInitialValues`,
  `ProviderContainer` with `sharedPreferencesProvider.overrideWithValue`.

## What was extended (additively, no breaking changes)

- `curriculum_loader.dart`: added `loadLearnCurriculum`,
  `LearnCurriculumNotifier`, `learnCurriculumProvider`,
  `kLearnCurriculumSchemaVersion`. Existing `loadCurriculum` /
  `CurriculumNotifier` / `curriculumProvider` / `loadAllQuizQuestions`
  untouched.
- `learn_screen.dart`: added AppBar action + `_SelectedLanguageBanner`.
  Existing lesson tree rendering untouched.
- `app_router.dart`: added `/learn/language` nested route. Existing
  routes untouched.
- `route_names.dart`: added `learnLanguageSelection` +
  `learnLanguageSelectionName`. Existing names untouched.
- `app_constants.dart`: added `keyLearnLanguage` + `learnCurriculumPath`.
  Existing constants untouched.
- `pubspec.yaml`: added `assets/curriculum/learn/` to assets. Existing
  entries untouched.
- `router_guard_test.dart`: added one assertion for `/learn/language`.
  Existing assertions untouched.

## What was NOT done (deliberate Part 0 boundaries)

- No actual language curricula. All 10 stubs return empty.
- No per-language XP isolation.
- No per-language mastery store (lessonId global keyspace).
- No localization of the app UI.
- No audio assets.
- No AI context provider changes (still reads Sanskrit curriculum state).
- No Exam Mode changes.
- No VAN changes.
- No production signing changes.

These land in Parts A–L as each language's curriculum ships and the
product evolves.

## Verification status

- **`flutter pub get`:** NOT RUN (Flutter SDK unavailable in sandbox).
- **`flutter analyze`:** NOT RUN (Flutter SDK unavailable in sandbox).
- **`flutter test`:** NOT RUN (Flutter SDK unavailable in sandbox).
- **Manual review:** all new code follows existing Riverpod 2.5 / Flutter
  3.6+ patterns already used in the codebase. All new imports verified
  against actual exports. All new widgets verified against `VaaniXScaffold`
  / `VanWidget` / `IconButton` APIs.

The user MUST run the three Flutter commands on their machine before
treating this Part as production-ready. Flagged in the CHANGELOG and in
the final Part 0 report.
