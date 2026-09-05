# Changelog

All notable changes to the VaaniX Flutter application.

## [Phase 3] - 2026-09-05

VAN experience completion. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 3 backlog).

### Added
- **The four dead VAN events are now dispatched** (previously declared with
  mapped reactions but never sent):
  - `streakExtended` — dispatched by the Nest after a genuine streak
    extension (day N card: "N-day streak — wonderful consistency!").
  - `onboardingCompleted` — dispatched at the nest reveal, so the
    controller-driven Van on Home greets the freshly onboarded learner.
  - `aiResponseFinished` — dispatched by the chat controller when a reply's
    reading window elapses. The speaking reaction no longer hard-cuts at
    its 2.2 s state default: the reply's window is passed via the new
    `VanEvent.displayDuration` (base 2200 ms + 24 ms per extra word,
    capped at 6 s), and the completion signal settles Van for real.
  - `userIdle` — decision recorded: **intentionally NOT dispatched in V1**
    (no genuine idle detector exists; a synthetic timer would fabricate
    companion behavior). The enum value stays reserved with settle-only
    semantics documented in `van_event.dart`.
- **Reaction cooldown**: `VanController` now honors the previously unused
  `AppConstants.vanIdleCooldownMs` (30 s) as a per-event-type cooldown for
  system-initiated companion-life reactions (`appOpened`,
  `streakExtended`, `onboardingCompleted`) — Home re-entry no longer
  re-greets over and over, and same-frame celebrations cannot stack.
  Deliberately ungated: per-answer task feedback, `companionTapped` play,
  milestone celebrations, and the whole AI/error lifecycle. The cooldown
  and clock are injectable for tests.
- **van_assets.json is the single catalog source**: the VAN animation
  catalog loads from `assets/van/metadata/van_assets.json` via the new
  `loadVanAssetCatalog()` loader + `vanAssetCatalogProvider` (Dart
  `VanAssetCatalog.v1` demoted to a malformed-asset fallback, same pattern
  as the curriculum loader). A parity test pins JSON ↔ Dart equality and
  one-visual-per-state coverage.
- **VanSpeechStrip wired** at its designed "exam preparation" surface:
  the exam instructions screen now opens with Van's encouragement strip
  (the widget existed but was never used).

### Fixed
- **Multi-achievement bursts consolidated**: the practice and exam screens
  dispatched one `achievementUnlocked` reaction AND one snackbar per
  achievement — bursts of non-interruptible celebrations that arbitration
  silently dropped, plus stacked snackbars. Both surfaces now emit a
  single consolidated celebration (first achievement + "(+N more)") for a
  batch, matching the lesson screen pattern.
- **VAN ticker pauses when offscreen**: the breathing motion controller
  used to tick forever. `VanWidget` now stops the ticker inside disabled
  `TickerMode` subtrees (covered/offstage routes, hidden tab children) and
  while the app is backgrounded (lifecycle paused/hidden), resuming from
  the stopped phase. The widget state is public (`VanWidgetState`) with a
  test-visible `motionController` getter.

### Tests
- 334 tests passing (314 existing + 20 new): JSON↔Dart catalog parity +
  loader fallback, per-type cooldown semantics (gated/ungated matrices),
  `displayDuration` fallback-clock behavior, ticker pause/resume under
  `TickerMode` and app lifecycle, chat reading-window units + full
  speaking→finished→idle lifecycle, consolidated exam achievements
  (updated exam journey to the new one-snackbar contract).

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
