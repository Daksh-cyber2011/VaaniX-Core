# Changelog

All notable changes to the VaaniX Flutter application.

## [Phase 2] - 2026-09-05

Learning / practice / exam / adaptive completion. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 2 backlog).

### Added
- **Single source of truth for the exam bank**: the question bank now loads
  from the JSON curriculum asset (`assets/curriculum/v1.json`) via the new
  `loadAllQuizQuestions()` loader. The compiled-in Dart bank
  (`chapterQuizzes`) is demoted to a malformed-asset fallback — exam
  content is byte-identical (pinned by a JSON↔Dart parity test). The exam
  session (`examQuizProvider`) became an async family so the bank load
  settles with a visible loading state instead of reading the hardcoded
  map; the pure `QuizNotifier` engine is unchanged and reused by the new
  controller (no logic drift).
- **Adaptive maps from the same source**: `quizIdCatalogProvider` and
  `quizIdsByChapterProvider` derive every quiz id from the JSON bank, so
  the exam flow and the adaptive engine can never drift apart. The dead
  `loadQuizForChapter`/`chapterQuizProvider` pair was removed.
- **Practice-session resume**: an in-progress practice session is
  snapshotted to storage after every state change (index, score, mastered
  ids) and restored on screen entry with a visible "picked up where you
  left off" cue. An app kill or accidental back-swipe no longer restarts
  practice from question 1. Fresh or finished sessions expire the
  snapshot; a full progress reset purges all `exercise_session_*` keys.
- **Attempt-history cap**: per-quizId attempt history is now capped at
  `AppConstants.maxAttemptsPerQuiz` (20) with the all-time best attempt
  ALWAYS retained — repeated retakes can no longer grow storage without
  bound, and best-score displays stay correct for the install lifetime.

### Fixed
- **Best-score display**: a chapter attempted with a 0% best was reported
  as "Exam not attempted" on the Progress screen (the provider dropped
  best == 0.0 entries, conflating "attempted with 0%" with "never
  attempted"). Attempted chapters now always appear; the exam result view
  likewise shows the real best (even 0/total) once any attempt exists.
- **Controller mutated during build**: the practice screen synced its
  translation `TextEditingController` and matching-chip state inside
  `build()` — moved into post-build `ref.listen` callbacks.
- The exam setup/instructions screens read the chapter list from the
  async JSON curriculum (Dart fallback retained) instead of the compiled
  constant.

### Tests
- 314 tests passing (293 existing + 21 new): JSON↔Dart bank parity,
  adaptive catalog derivation, async exam session (selection / restart /
  empty-config), attempt-cap trimmer + repository-level cap with
  best-preservation, session-snapshot reset purge, 0%-attempted chapter
  display, exercise resume engine + widget resume/persist/expire flows.

## [Phase 1] - 2026-09-05

Core student product loop repairs. Full audit basis: `docs/Audits/V1-Audit-Phase0.md`.

### Fixed
- **Build blockers**: `chat_screen.dart` re-encoded as valid UTF-8 (raw CP1252
  bytes made Dart treat the file as binary, breaking the router import);
  `CardTheme`/`DialogTheme` replaced with `CardThemeData`/`DialogThemeData`
  in `app_theme.dart` (4 sites) — `flutter analyze` is now clean on modern
  stable toolchains.
- **Exam autosave**: finishing a quiz now persists the attempt, XP and the
  achievement check automatically. The previous manual-only Save button
  meant an app kill on the result screen silently lost the result. The Save
  button remains as visible confirmation + retry path, with an honest label
  (no XP promised on repeat completions).
- **Achievement bonus XP ledger**: bonus XP no longer flows through
  `completeLesson()` with synthetic `ach_*` lesson ids, which inflated
  lesson counts, journey % and the adaptive subtitle. New idempotent
  `awardBonusXp` repository API backed by a dedicated ledger; legacy
  polluted lesson-id lists are sanitized on startup.
- **Streak achievements**: Home now runs the achievement checker after
  recording daily activity, so 3-day / 7-day streaks unlock from streak
  activity alone. A failed streak write no longer stamps a false
  `lastActiveDate`.
- **Practice completion**: a persistence failure no longer leaves the
  complete button permanently disabled with no feedback (try/catch/finally
  + error snackbar, mirroring the lesson-content pattern).
- **Lesson completion ordering**: the reactive completed-lesson list now
  commits only after a successful repository write (previously optimistic,
  leaving stale in-session state on failure).
- **QuizNotifier**: an empty question bank now fails with a clear
  `StateError` instead of a confusing `clamp()` ArgumentError.
- **Mojibake**: corrupted em-dash characters fixed in user-visible strings
  (exam feedback, onboarding copy) and section-banner comments.

### Changed
- Analyzer now excludes `Archive/**` (historical snapshots) so `flutter
  analyze` reflects the real project.
- Pubspec SDK floor raised to Dart >= 3.6.0; README documents the verified
  toolchain (Flutter >= 3.32, tested on 3.47.2).
- Transitive dependency refresh from `flutter pub get`.

### Tests
- 293 tests passing (282 existing + 11 new): exam autosave E2E, bonus-XP
  ledger, legacy sanitize, streak achievement trigger, streak-write failure
  isolation, lesson-completion rollback, empty-bank guard.

## [5.0.0] - 2026-07-30

### Added
- Complete Clean Architecture restructure (app/core/features/shared layers)
- Core auth abstraction (`CoreAuthRepository`, `AuthSession`, `AuthUser`) in `core/auth/`
- `SessionManager` with dependency inversion (core owns the contract, feature supplies impl)
- `NavigationService` for context-free programmatic navigation
- `ConnectivityService` with reactive online/offline providers
- `DioClient` with auth, logging, and retry interceptors (exponential backoff + jitter)
- `ILocalStorageService` abstraction with typed SharedPreferences implementation
- `AppLogger` structured logging facade (debug → prod stub ready)
- `AppLifecycleObserver` reactive provider
- Full Material 3 theme system (light + dark) with `ThemeNotifier`
- `FeatureFlags` gating for unfinished modules
- Complete onboarding flow (6 pages: name, personality, subject, goal, auth, nest reveal)
- Splash screen with animated logo and routing decision
- Auth screen (Google + Phone UI, wiring ready)
- Home screen (The Nest) with Van companion, streak/XP badges
- Settings screen with theme toggle and learning profile display
- 14 shared widgets (VaaniXCard, VanWidget, PrimaryButton, etc.)
- String, DateTime, BuildContext, Int extension methods
- `go_router` with `StatefulShellRoute` and declarative redirect guards
- `.gitignore` covering Flutter, secrets, IDEs, and generated files
- `.env` untracked from git history

### Changed
- All imports converted to `package:vaanix_app/...` (zero relative imports)
- `core/config/` renamed to `core/environment/`
- `core/bootstrap/` moved to `app/bootstrap/`
- `core/router/` moved to `app/router/`
- `core/utils/logger.dart` moved to `core/logging/`
- `core/utils/app_lifecycle_observer.dart` moved to `core/lifecycle/`
- `core/providers/navigation_service.dart` moved to `core/navigation/`
- `core/utils/extensions.dart` moved to `shared/extensions/`
- Documentation folders consolidated under `docs/`
- Old code versions archived to `Archive/`

### Removed
- Unused dev-dependencies: `freezed`, `json_serializable`, `build_runner`, `riverpod_generator`, `riverpod_annotation`
- `assets/env/.env` from Flutter asset declaration
