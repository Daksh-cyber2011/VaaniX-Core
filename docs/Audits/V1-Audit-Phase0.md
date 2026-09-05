# VaaniX V1 — Phase 0 Completion Audit

**Audit date:** 2026-09-05 · **Commit audited:** `48d9f59` (main) · **Method:** full source read of all 148 `lib/` + 33 `test/` files, toolchain-verified (`flutter analyze` + `flutter test` executed on Flutter 3.47.2 / Dart 3.13.2), Android/iOS/security/docs sweeps.

---

## 1. Executive Summary

VaaniX V1 is a **substantially real, well-engineered product** — not a scaffold. The core student loop (onboarding → home → learn → practice → exam → results → progress → adaptive next action) is genuinely wired end-to-end against persisted state. The AI tutor pipeline is production-grade (real Gemini adapter, real offline tutor, confirmed LearningContext injection). The test suite (**282 tests**) passes in full on Flutter 3.47.2.

However, the repo **does not compile as committed on the latest stable toolchain** (6 analyzer errors), the exam result depends on a manual Save tap, achievement bonus XP corrupts lesson counts, and 4 of 18 VAN events are declared but never dispatched. Release readiness (signing, icons, iOS Podfile) is absent. All findings below carry file:line evidence.

---

## 2. Toolchain Verification (actually executed)

| Check | Result |
|---|---|
| `flutter pub get` (Flutter 3.47.2 / Dart 3.13.2) | OK |
| `flutter analyze` (real `lib/` + `test/`, Archive excluded) | **6 errors**, 0 warnings-in-lib |
| `flutter test` | **282 / 282 PASSED** (38s) |
| `flutter build apk` | NOT RUN — no Android SDK in audit environment (see §6 Blocked) |
| Secrets sweep (keys/DSN/.env history decode) | **CLEAN** — no real credential ever committed |
| Curriculum integrity | UNCHANGED — JSON↔Dart parity tests pass; zero curriculum edits made |

**The 6 compile-blocking errors:**

1. `lib/features/ai/presentation/screens/chat_screen.dart` — **invalid UTF-8** (raw CP1252 `0x80` at byte 14). Dart treats the file as binary → `app_router.dart:21` import fails → `ChatScreen` unresolvable → **app target cannot compile**. Introduced by the latest commit `48d9f59` (an encoding cleanup that wrote CP1252 bytes instead of UTF-8). This is why the analyzer reports "URI doesn't exist" for a file that is visibly present.
2. `lib/core/theme/app_theme.dart:206,216,423,431` — `ThemeData.cardTheme`/`dialogTheme` receive `CardTheme`/`DialogTheme` instead of `CardThemeData`/`DialogThemeData` (API removed in recent Flutter). Introduced in `691226b`.

Both are mechanical fixes (re-encode one file; swap 4 class names) — scheduled as the first action of Phase 1. Tests pass because the test suite does not import the router.

**Toolchain note:** `.metadata` records project creation at Flutter 3.44.9; `android/` uses AGP 9.0.1 / Gradle 9.1.0 / Kotlin 2.3.20. The committed `CardTheme` usage implies the last verified analyze ran on an older Flutter. Phase 1 must pin the intended SDK and keep `flutter analyze` green on it.

---

## 3. V1 Completion Matrix

| # | Category | Status | Evidence (what exists) | Missing Work | Phase |
|---|---|---|---|---|---|
| A | Student Onboarding | 🟢 COMPLETE | 6 persisted steps (`onboarding_provider.dart:68-100`), restart hydration (`:35-46`), router gate (`app_router.dart:66-69`), offline auth skip (`ob_auth_page.dart:34`), NoopAuthRepository fallback | Page index not persisted; no re-run entry; no VAN `onboardingCompleted` event; no Phone OTP (doc claims it) | 3, 5 |
| B | Home / Nest | 🟢 COMPLETE | Every card consumes live providers (`home_screen.dart:55-63,136,159-161`); adaptive CTA routes correctly (`:66-93`); streak recorded on open; VAN greeting on `appOpened` | VAN greeting limited to `appOpened` lifecycle | 3 |
| C | Learn | 🟡 PARTIAL | 4 chapters / 13 lessons, all with full markdown content (`sanskrit_lesson_content.dart` + `unit2_lesson_content.dart`), async JSON loader + Dart fallback (`curriculum_loader.dart:27-65`), custom markdown renderer, scroll-gated completion, XP idempotent | No lock/unlock or prerequisites; `selected_class` (CBSE 6-10) has no effect on curriculum; no audio/media | 2, 5 |
| D | Exercise Engine | 🟡 PARTIAL | All 5 types implemented + validated + tested (`exercise_models.dart:17-150`, `exercise_providers.dart:200-283`), deterministic shuffle, first-try scoring, mastery persisted, explanations/hints | **`translation` + `matching` have zero authored content** — engine exists but is unreachable (52 exercises are mcq/fillBlank/ordering only). ⚠ Authoring new exercises touches curriculum content → needs explicit owner approval | 2 (content gated) |
| E | Adaptive Learning | 🟢 COMPLETE | Deterministic priority engine (`adaptive.dart:137-258`); wired into Home hero CTA, Progress NEXT FOCUS, AI LearningContext (`learning_context_provider.dart:31-32`); refreshed after exam save | Quiz-id maps duplicated in Dart (`adaptive_providers.dart:23,89`) risk drift from JSON | 2 |
| F | Progress | 🟡 PARTIAL | Real XP/level curve (`gamification.dart:16-43`), streak + last-active, weak areas + exam-best from persisted attempts, thorough reset with prefix-purge | **Defect: achievement bonus XP writes synthetic `ach_*` ids into `completed_lesson_ids`** (`achievement_checker.dart:95-103`) inflating lesson counts everywhere; no backend sync (by design, documented) | 1 |
| G | Exams | 🟡 PARTIAL | Full setup→instructions→quiz→result lifecycle, 32 grounded MCQs, per-chapter difficulty, attempt history, idempotent XP | **Result persists only via manual Save** (`exam_screen.dart:333-341`) — app kill loses attempt/XP/achievement check; XP label over-promises on repeats (`:846`); no shuffle/timer/variants | 1, 2 |
| H | VAN | 🟡 PARTIAL | 11-state declarative machine with priority + interruptibility + stale-timer protection (`van_state.dart`, `van_controller.dart:81-90`), polished vector fallback painter (`van_widget.dart:343-624`), 22 controller tests | **4/18 events never dispatched**: `streakExtended`, `onboardingCompleted`, `aiResponseFinished`, `userIdle`; `vanIdleCooldownMs` declared but unused; `van_assets.json` never parsed (catalog duplicated in Dart); ticker never pauses | 3 |
| I | AI Tutor | 🟡 PARTIAL | Real Gemini adapter (30s timeout, sanitization, typed failures), **LearningContext confirmed injected into persona** (`default_prompt_pipeline.dart:71-76` ← `learning_context.dart:136-165`), real offline tutor (677 lines, 12 intents), rate limiter, cache, safety filter, token tracker, persisted conversations | Streaming path dead (no production caller); unbounded message lists in memory + storage; learner `displayName` hardcoded `''` (`chat_controller.dart:96`); Gemini client rebuilt per turn (persona embeds per-turn context); usage chip stale | 4 |
| J | Profile / Settings | 🟡 PARTIAL | Theme persistence, inline profile editors, streak reset, comprehensive progress reset with provider invalidation (`settings_screen.dart:534-552`) | **Reset misses AI subsystems** (conversations, response cache, token usage — `token_usage_tracker.dart:109` even says it should be called); no onboarding reset; "Reset to default" mislabeled (sets cheerleader) | 4, 5 |
| K | Offline Experience | 🟢 COMPLETE | Bootstrap survives missing/malformed `.env` (test-verified `bootstrap_offline_test.dart:40-74`); Supabase doubly-guarded + optional; Gemini falls back to real offline tutor; no startup network calls | `SENTRY_DSN` in `.env` is dead config (dart-define only, `main.dart:29`) — docs contradict | 6 |
| L | UI/UX | 🟡 PARTIAL | Coherent M3 theme, Poppins wired, light/dark, shared widget library, empty/error/loading/offline states implemented, reduced-motion support in VAN | **Mojibake in user-visible strings** (`exam_screen.dart:368,579`, `ob_goal_page.dart:94`, `ob_auth_page.dart:148`); /chat + /achievements missing from route guards; a11y/touch-target sweep pending | 5 |
| M | Analytics | 🟢 COMPLETE | Typed events (`analytics_event.dart`), no-op production provider, bounded emission, debug-only visibility; core test covers contract | — | — |
| N | Security | 🟢 COMPLETE | No secrets anywhere (sweep incl. git-history .env decode — all placeholders); placeholder values actively rejected (`app_environment.dart:45-52`); tokens never logged; `.gitignore` covers keystores | Gemini key ships inside APK as bundled asset (accepted V1 model; proxy recommended at scale) | 6 (note) |
| O | Android / Release | 🟡 PARTIAL | Correct applicationId/namespace `com.vaanix.app`, minimal INTERNET-only permissions, embedding v2, dark launch theme | **Debug-signed release config** (`app/build.gradle.kts:29-32`), no keystore (external), SDK versions unpinned, template launcher icons (no adaptive), leftover `com/example/MainActivity.kt`, **iOS has no Podfile**, web icon refs broken | 6 |
| P | Performance / Quality | 🟡 PARTIAL | Good dispose/mounted hygiene across UI, zero-division guards everywhere, stale-timer protection in VAN, disposal-race tests for chat | Unbounded AI transcript storage; VAN ticker runs offscreen; controller mutated during build (`exercise_screen.dart:145-147`); append-only quiz attempt history | 2, 3, 4 |

**Legacy snapshot pollution:** `Archive/Code 1.0–4.0/` contains four full historical project copies. They inflate `flutter analyze` to 837 issues and confuse tooling. Phase 6 should either delete or exclude them (`analyzer.exclude`) — content is preserved in git history anyway.

---

## 4. Defect Register (priority-ordered, all file:line verified)

### P0 — Breaks build or core promise
1. `chat_screen.dart` invalid UTF-8 → app target unresolvable (§2). Introduced `48d9f59`.
2. `app_theme.dart` ×4 CardTheme/DialogTheme type errors (§2). Introduced `691226b`.
3. Exam result lost on app kill — persistence is a manual button (`exam_screen.dart:333-341,843-849`).
4. Achievement bonus XP pollutes `completed_lesson_ids` with `ach_*` ids → inflated journey %, lesson stats, adaptive subtitle (`achievement_checker.dart:95-103`).

### P1 — Wrong behavior users can see
5. Streak achievements unreachable from streak activity alone (`home_screen.dart:55-63` never calls checker).
6. Exam Save button over-promises XP on repeat completions (`exam_screen.dart:846` vs `local_progress_repository.dart:77`).
7. Practice-completion failure leaves `_isCompleting` stuck true, no error surface (`exercise_screen.dart:86-106`).
8. Optimistic lesson completion without rollback (`progress_providers.dart:51-55`).
9. Settings reset leaves AI conversations/cache/usage behind (`settings_screen.dart:533-560`).
10. Mojibake in user-visible strings (4 strings) + corrupted comment banners (7 files total).
11. VAN: `aiResponseFinished` never dispatched — speaking state hard-cuts at 2200ms (`chat_controller.dart:190`); `streakExtended`/`onboardingCompleted` dead despite mapped reactions.

### P2 — Robustness / hygiene
12. Unbounded growth: AI transcripts (memory+disk), `ai_conversation_*` keys, quiz attempt lists, token-usage history.
13. VAN: no cooldown (`app_constants.dart:97` unused); motion ticker never pauses offscreen; multi-achievement dispatch loops.
14. Data split-brain: exam bank + adaptive quiz maps hardcoded in Dart while curriculum tree comes from JSON (`chapterQuizProvider` exists, unused).
15. `QuizNotifier.current` RangeError when bank empty (`quiz_providers.dart:102-103`).
16. Streak state drift on repo failure (`profile_providers.dart:86-91`); stale AI usage chip (`chat_screen.dart:84-86`).
17. Route-guard gap for `/chat`, `/achievements`; `onboardingScreenCount` constant = 7 vs 6 pages.
18. `van_assets.json` dead data (catalog duplicated in Dart); `VanSpeechStrip` built but unused; dead infra: full Dio stack, NavigationService, `app_state.dart` flags, `cached_network_image`, `flutter_svg`.

---

## 5. Prioritized Backlog (mapped to phases)

**Phase 1 — Core student product loop (do first)**
1. Fix the 6 compile errors + pin toolchain (re-encode chat_screen.dart as UTF-8; CardThemeData/DialogThemeData; record min Flutter in README/docs).
2. Exam autosave on quiz finish (keep Save as UX, not sole write path) + honest XP label.
3. Achievement XP ledger: stop writing `ach_*` into `completed_lesson_ids` (separate XP award path or filter prefix at all count sites).
4. Streak achievements: call checker after `recordDailyActivity`.
5. Practice completion try/finally + error snackbar; optimistic-completion rollback.
6. Regression tests for each fix.

**Phase 2 — Learning / practice / exam / adaptive completion**
1. Route exam bank + adaptive maps through the JSON loader (single source; content unchanged).
2. Exercise-session resume (persist in-progress state).
3. Cap attempt history; empty-bank guard; best-score display fix.
4. ⚠ BLOCKED pending owner decision: authoring `translation`/`matching` exercise content (curriculum freeze — engine ready).

**Phase 3 — VAN experience completion**
1. Dispatch `streakExtended` (after streak record), `onboardingCompleted` (nest reveal), `aiResponseFinished` (chat success), `userIdle` (only if a genuine detector exists — else document removal).
2. Implement reaction cooldown using `vanIdleCooldownMs`; consolidate multi-achievement bursts.
3. Load `van_assets.json` as the single catalog source; pause ticker when offscreen; wire `VanSpeechStrip` where designed.

**Phase 4 — AI tutor + learning intelligence**
1. Streaming: wire `pipeline.stream` into ChatController or remove dead path + `enableStreaming` flag.
2. Cap stored transcripts + prune `ai_conversation_*`; per-turn context out of the Gemini system instruction (pass as message content) to restore client caching.
3. Learner `displayName` personalization; refresh usage chip after sends; hook AI clears into Settings reset.

**Phase 5 — UI/UX + product polish**
1. Mojibake cleanup (strings first, comments second); route-guard gap; touch targets/a11y sweep; dark-mode audit; onboarding page-index persistence; personality-reset label.

**Phase 6 — Final production readiness**
1. Android release: signing config (external keystore), pinned SDK versions, adaptive icons, remove `com/example` leftover; regenerate iOS Podfile; fix web icon refs.
2. Decide Archive/ fate (delete or analyzer-exclude); docs hygiene: rewrite `AI-Architecture.md` (currently a leaked developer prompt), fill empty `Master-Van-Bible.md`, de-duplicate Constitution.md, refresh stale test counts in EngineeringCompletionReport.md.
3. Remove dead infra (Dio stack or wire it; NavigationService; app_state flags; 2 dead deps) — or explicitly justify keeping.

---

## 6. Blocked / External Items

| Item | Blocker | Action required |
|---|---|---|
| Canonical VAN Lottie/Rive animations | No art assets exist; `van_assets.json` marks all 11 `pending_art` | External art delivery; vector fallback remains production renderer until then |
| Android release signing | No keystore/credentials (by design, gitignored) | Owner generates keystore + `key.properties` |
| APK build verification in this audit | No Android SDK in audit environment | Run `flutter build apk --debug` in Android-equipped env (dev machine previously succeeded: ~192.9 MB debug APK) |
| Translation/matching exercise content | Curriculum freeze | Owner authorizes content authoring |
| Backend/Supabase sync | Local-first by design; no Supabase project configured | Owner provisions project; sync architecture documented in `docs/Product/Sync-Architecture.md` |
