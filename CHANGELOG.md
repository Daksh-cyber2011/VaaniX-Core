# Changelog

All notable changes to the VaaniX Flutter application.

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
