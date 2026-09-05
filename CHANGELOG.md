# Changelog

All notable changes to the VaaniX Flutter application.

## [Phase 6] - 2026-09-05

Final production readiness. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 6 backlog; legacy snapshot
pollution note).

### Added
- **Android adaptive launcher icon** (API 26+): `mipmap-anydpi-v26`
  descriptor with the existing launcher art inset into the adaptive safe
  zone (foreground layers generated per density) over the app's light
  surface color (`@color/ic_launcher_background` = `#FAF8F4`, matching
  `AppColors.backgroundLight`). Legacy raster icons below API 26 unchanged.
- **Android release signing scaffold**: `build.gradle.kts` reads
  `android/key.properties` (gitignored) and signs release builds with the
  real keystore when present, falling back to the debug key otherwise so
  `flutter run --release` keeps working. Generation instructions live in
  the file header. The keystore itself remains an external owner item.
- **iOS `Podfile`** regenerated (platform 13.0, matching
  `IPHONEOS_DEPLOYMENT_TARGET` in `Runner.xcodeproj`): standard Flutter
  podhelper setup with the `RunnerTests` search-paths inheritance.
- **Resource-integrity regression tests**
  (`test/platform/platform_asset_refs_test.dart`): web manifest icons must
  exist with declared pixel sizes, `index.html` references must resolve,
  adaptive-icon layers must exist at all densities, `com/example` must
  stay deleted, the Podfile must pin platform 13.0, and the removed dead
  dependencies must stay out of `pubspec.yaml`.
- **`ExceptionMapper` matrix tests** (`test/core/exception_mapper_test.dart`):
  full retained mapping surface (Supabase auth branches, domain
  exceptions, timeouts, unknown fallback, Failure passthrough) pinned
  after the Dio branch removal.

### Changed
- **Android SDK levels pinned** in `app/build.gradle.kts`
  (minSdk 24 / targetSdk 36 / compileSdk 36 — Flutter 3.47 toolchain
  defaults made explicit) so toolchain upgrades cannot silently move the
  platform contract; stale `applicationId` TODO removed (identity is
  `com.vaanix.app`).
- **Web presence fixed and branded**: `manifest.json` now references the
  icons that actually ship (`Icon-maskable-192/512.png` — the template
  referenced `Icon-192/512.png` which were never committed), and
  name/description/theme colors use VaaniX branding instead of Flutter
  template defaults; `index.html` apple-touch-icon, title and meta
  description aligned.
- **`docs/Product/AI-Architecture.md` rewritten** — it contained a leaked,
  voice-transcribed developer prompt; it is now a real architecture
  document describing the implemented pipeline (safety → prompt → rate
  limit → cache → adapter), streaming semantics, bounds, personalization,
  grounding rules and the testing map.
- **`docs/VAN/Master-Van-Bible.md` filled** (was empty): master reference
  indexing the eight design chapters, the implemented event/state/cooldown
  system, the pending-art status and the no-fake-events rule.
- **`docs/Constitution/Constitution.md` de-duplicated** — every article was
  repeated 6–7 times (183 → ~60 lines, each article once); README status
  updated.
- **`docs/EngineeringCompletionReport.md` refreshed**: point-in-time body
  annotated, resolved `applicationId` blocker marked, and a Phase 0–6
  addendum added with the current phase/commit/test ledger.

### Removed
- **`Archive/`** (four historical project copies, 267 tracked files,
  2.3 MB) — deleted from the working tree; content preserved in git
  history. Analyzer exclusion entry retired with it.
- **Dead infrastructure**: the standalone Dio stack
  (`dio_client.dart` + auth/refresh-token/logging/retry interceptors —
  nothing ever constructed a `DioClient`; HTTP transport lives in the
  Gemini adapter and Supabase clients), `NavigationService` (its provider
  was never watched; `navigator_keys.dart` stays — the router owns
  `rootNavigatorKey`), and `core/providers/app_state.dart`
  (`globalLoading`/`appInitStatus`/`FeatureFlags` — never consumed). The
  `ExceptionMapper` Dio branch, the core barrel exports and the stale
  logger example were updated accordingly.
- **Dependencies** `dio`, `cached_network_image`, `flutter_svg` (zero
  imports across lib/ and test/).

### Verification
- `flutter analyze`: 0 issues.
- `flutter test`: 415/415 (387 + 28 new).
- `assets/curriculum/v1.json` untouched (content freeze respected).

## [Phase 5] - 2026-09-05

UI/UX + product polish. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 5 backlog; rows A, J, L;
defects #10, #17).

### Fixed
- **Route-guard gap (defect #17)**: `/chat` and `/achievements` are
  pushed on top of the shell and were missing from the protected-route
  set — with Supabase configured, a deep link straight to either screen
  bypassed the auth gate every other screen honors. Both are protected
  now, and the match is prefix-aware so nested sub-routes (e.g.
  `/learn/lesson/:id/practice`) cannot slip through either. The redirect
  decision was extracted into pure, `@visibleForTesting` functions
  (`guardRedirect` / `isProtectedLocation`) so the full gate matrix
  (onboarding × auth × every route family, offline vs backend) is pinned
  by tests.
- **Onboarding page-count drift (defect #17)**:
  `AppConstants.onboardingScreenCount` claimed 7 (the PRD §8.1 screen
  count including the splash) while the flow hosts 6 pages — and the
  constant was never referenced, with `6` hardcoded in two places. The
  constant now reads 6, carries a doc explaining the splash distinction,
  and both the notifier clamp and the screen's dot indicators derive
  from it (single source).
- **Onboarding restart lost progress (row A)**: a mid-onboarding app
  restart dropped the learner back to page 0. The last page index is now
  persisted on every move, hydrated on restart (clamped against the
  page count to defend against stale values), ignored once onboarding
  completed, and cleared on completion so no stale index survives.
- **"Reset to default" was mislabeled (row J)**: the Van Profile button
  forced `PersonalityMode.cheerleader` — the first option in the picker,
  not a default — and once a mode was chosen there was NO way back to
  the un-personalised state (`copyWith` cannot null a field out). A real
  clear path now exists: `UserProfileRepository.clearPersonalityMode()`
  removes the storage key, and the notifier rebuilds the state with a
  null mode (identity fields kept). Van returns to his default greeting,
  Settings shows "Not set", and the choice stays re-selectable.
- **Dark-mode contrast defects (row L, a11y/dark sweep)**: 20+
  user-visible elements used light-theme-only `AppColors` tokens
  unconditionally, washing out or disappearing in dark mode — chat
  usage-dialog body text, typing-indicator dots, Van-bubble timestamps,
  chat input hints, onboarding inactive page dots, onboarding name/auth
  copy and "or" divider, subject/goal card borders and icon tints, exam
  filter-chip borders, progress chevrons, locked-achievement icon tints,
  auth screen copy, the exercise screen's `?? Colors.white` card
  fallback, and the Van profile personality tiles. All now resolve the
  themed token per brightness. The Settings screen's redundant nested
  brightness ternary (dead inner branch) was collapsed.

### Changed
- **Mojibake sweep final pass (defect #10)**: the last corrupted byte
  sequence (`â†'` for `→`) in `app_router.dart`'s NavigationService doc
  comment is fixed. A full-codebase re-verification (grep signatures +
  UTF-8 validation of every .dart file) confirmed the string-level
  mojibake flagged in the audit was already cleaned in earlier phases —
  the remaining flagged sites were legitimate em-dash typography.
- **Accessibility sweep (row L)**: every icon-only `IconButton` now
  carries a tooltip/semantic label (password visibility toggle, chat
  error dismiss, send, onboarding back + name clear, lesson/practice
  back, matching remove-match). The onboarding back button's tap target
  is held at the 48px Material minimum (M3's default is 40px, its icon
  is 20px).

### Tests
- 29 new tests: `test/app/router_guard_test.dart` (10 — full guard
  matrix incl. the /chat//achievements regression), 
  `test/features/onboarding/onboarding_page_persistence_test.dart`
  (12 — persist/hydrate/clamp/clear/no-op-move/constant), and
  `test/features/profile/personality_reset_test.dart` (7 — repo clear,
  notifier state rebuild, identity fields kept, storage key removed,
  survives reload). Suite: 387 passed (was 358).

## [Phase 4] - 2026-09-05

AI tutor + learning intelligence. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 4 backlog).

### Added
- **Streaming replies are live**: the previously dead `pipeline.stream`
  path (fully built, never called — audit row I) is now wired into the
  chat controller behind the existing `AiConfig.enableStreaming` flag
  (production default ON). Deltas render into the trailing message bubble
  in place, so Van's reply grows while it is generated — a real win on
  slow connections and for the offline tutor's word-by-word cadence.
  Success drives the identical Van speaking lifecycle, achievement check
  and usage-chip refresh as the complete path; `enableStreaming: false`
  still routes through `send()` (pinned by tests).
- **Honest streaming failure semantics**: a failed stream withdraws the
  partial bubble (the pipeline persists nothing on failure — UI and
  memory stay consistent), a stream that ends with no content surfaces an
  error instead of a fabricated empty success, and an unsafe ASSEMBLED
  reply is re-checked with the same SafetyFilter the pipeline uses, so
  text that would not be persisted is never left dangling on screen.
- **Learner display name (personalization)**: `UserProfile.displayName`
  (Settings → LEARNING PROFILE → "Your Name", editable + clearable) is
  persisted through the profile repository and flows into
  `LearnerContext.displayName` — the Gemini persona addresses the learner
  by name and the offline tutor's greetings personalize (`_greet(name)`)
  instead of the previous hardcoded `''`. Empty = anonymous by design.
- **`dailyUsageProvider`**: today's AI usage is a watched FutureProvider;
  the ChatController invalidates it after every successful turn.

### Fixed
- **Stale usage chip (defect #16)**: the Chat screen's remaining-quota
  chip read the tracker exactly once per screen build via a
  `FutureBuilder` and never refreshed — it now watches
  `dailyUsageProvider` and updates immediately after each send.
- **Settings reset missed the AI subsystem (defect #9)**: Reset Progress
  now also clears persisted conversations (`clearAll`), the response
  cache and the token-usage history (whose `clear()` documented "used by
  Settings → reset" but was never called), and invalidates the chat
  controller + usage chip so the UI reflects it instantly. The reset
  dialog copy says so.
- **Per-turn context no longer churns the Gemini system instruction**:
  the bounded learning snapshot was embedded in the persona/system
  instruction, forcing a `GenerativeModel` rebuild on EVERY request
  (client caching defeated). The persona is now stable across turns and
  the snapshot travels as framed per-turn message content
  (`ConversationContext.learningContextMessage`, header/footer markers in
  `AppConstants`), appended by the adapter to the outgoing user turn —
  the model client is reused for the adapter's lifetime.
- **Duplicated outgoing turn in Gemini history**: the request history was
  built from the full transcript INCLUDING the last user message, which
  was then sent again via `sendMessage` — the model saw every new message
  twice. `buildRequestHistory` now excludes the outgoing message.
- **Bounded AI transcripts (defect #12)**: persisted conversation
  transcripts are capped at `AppConstants.maxAiTranscriptMessages` (100,
  newest kept); conversation KEYS are pruned to the newest
  `maxStoredAiConversations` (5) by the `conv_<millis>` timestamp
  (timestamp-less legacy ids sort oldest); and `clear()` now REMOVES the
  storage key instead of writing an empty-list zombie. The
  `ai_conversation_` prefix lives in a single constant.

### Tests
- 358 tests passing (334 existing + 24 new): progressive rendering +
  failure/empty/unsafe withdrawal semantics, streaming Van lifecycle,
  usage-provider invalidation, display-name stamping, mid-stream dispose
  safety; transcript cap sliding window, key removal, conversation
  pruning (newest-kept, current-never-pruned, legacy-ids-first); Gemini
  request shaping (history excludes outgoing turn, sanitizer applied,
  stable instruction across turns, framed context message); Settings
  reset widget test driving the REAL flow (AI keys cleared, identity
  kept); display-name persistence round-trip. The learning-context
  pipeline tests were re-pinned to the new stable-persona contract, and
  the race/speaking controller tests now explicitly pin the complete-turn
  path while production defaults to streaming.

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
