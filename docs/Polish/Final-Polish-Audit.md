# VaaniX — Final Polish & Production Experience Audit

**Milestone:** Final Polish & Production Experience ("Million-User Quality")
**Base:** `VaaniX-Learn-2.0-M12-Final-Freeze.zip` (SHA256 `9bfde3bc…da33b01`, 1347 entries)
**Date:** 2026-09-12
**Scope:** whole application (Learn Mode, Home/Nest, onboarding, auth, navigation, VAN,
AI chat, progress, achievements, settings, profile) — **Exam Mode excluded** except two
2-line shared-system fixes (documented below).

This document is the audit performed **before** any change, per the milestone contract.
Each finding was verified against source before being accepted; several candidate issues
raised during scanning were rejected as false positives or intentional design (listed at
the end).

---

## 1. What was audited

- All 24 screens/surfaces (`rg`-enumerated), read line-by-line: splash, router,
  bootstrap, main, 6 onboarding pages, auth, home/Nest, learn shelf, diagnostic,
  session, smart practice, lesson content, exercise, learn profile, language picker,
  AI chat + widgets, achievements, progress, settings, VAN profile, exam (read-only).
- The design system: `core/theme/*` (colors, dimens, motion, shadows, text styles,
  theme notifier) and all 18 `shared/widgets/*` including the VAN trio.
- VAN end-to-end: asset catalog contract (JSON + Dart parity), renderer, fallback
  painter, controller arbitration, all ~38 usage sites.
- AI pipeline failure paths: adapter stream/complete, exception mapper, rate limiter,
  response cache, offline tutor, chat controller state machine.
- Connectivity: `connectivity_service`, `OfflineBanner` coverage, offline honesty of
  every network-dependent surface.
- Language/RTL: Urdu plumbing per screen, script coverage of bundled fonts, mixed-
  script rows, bidi hazards.
- Debt scan: TODO/FIXME/print/debug text (clean), unused imports, dead widgets.

## 2. Verified defects (fixed in this milestone)

### A. Production-critical
| # | Where | Defect |
|---|-------|--------|
| A1 | onboarding `ob_nest_reveal_page.dart:98` | Raw exception interpolated into a first-run SnackBar (`Could not complete onboarding: $e`). |
| A2 | AI chat (`gemini_model_adapter.dart:464`, `chat_controller.dart:341/383`) | Unmapped SDK exceptions reach the chat error banner as raw/lowercased `error.toString()`. |
| A3 | `auth_screen.dart:131` | Unmapped auth failures surface raw `failure.message` (Supabase internals possible). |
| A4 | `smart_practice_screen.dart:531/640/870/877/924` | `AppColors.subtextLight` used unconditionally — dark theme renders washed-out grey-on-dark (contrast bug). |
| A5 | systemic (~20 sites: progress, achievements, settings, chat) | `AppColors.primary` (light indigo #3B4CCA) used for text/icons on dark surfaces — ~2.8:1 contrast, fails WCAG non-text minimum. |
| A6 | navigation | Chat / Settings / Achievements opened via `context.go()` from outside the shell: no back button, system back **exits the app** — user feels trapped. |
| A7 | `auth_screen.dart` "Skip for now" | When Supabase is configured the router guard bounces `/home → /auth`, so Skip silently loops back to the same screen. |
| A8 | `progress_screen.dart:56` | No loading/error branch for `curriculumProvider`: silent zeros, chapters vanish, no retry. |
| A9 | `exercise_screen.dart:835` | Matching review label concatenates left+right with no separator (`پانیwater`). |
| A10 | `exercise_screen.dart` (whole screen) | No RTL plumbing although it serves Urdu exercises; Urdu prompts/options/typed answers render LTR. |
| A11 | `diagnostic_screen.dart` (whole screen) | Same RTL gap for Urdu probe banks. |

### B. Accessibility (WCAG / TalkBack)
| # | Where | Defect |
|---|-------|--------|
| B1 | `diagnostic_screen.dart` `_ChoiceTile`/`_PairTile` | No Semantics on interactive tiles (exercise/session already have the pattern — parity gap). |
| B2 | `smart_practice_screen.dart` `_KindChip` + generated-quiz options | No Semantics; 14×14 AI spinner silent. |
| B3 | `learn_screen.dart` ×3 cards, `learn_profile_screen.dart` level-check card | Tappable cards missing `Semantics(button:)`. |
| B4 | `exercise_screen.dart:444` header progress | Missing `semanticsLabel` (siblings have it). |
| B5 | five sites | Touch targets < 48dp (kind chips, minute chips, match/pair tiles, app-bar mini-Vans). |
| B6 | `onboarding_screen.dart` page dots | Position ("Page 2 of 6") never announced. |
| B7 | `ob_name_page.dart` | Name field has hint only, no `labelText`. |
| B8 | `exam_screen.dart:279` | Bare unlabelled spinner (sibling at :483 is labelled) — 2-line shared-a11y fix, in scope. |
| B9 | `exam_screen.dart:495/525` | Failure shown with VAN `thinking` expression instead of `error` — VAN context correctness, 2-line fix, in scope. |
| B10 | `chat_input.dart:136` send spinner | No `semanticsLabel`. |
| B11 | small app-bar VANs (chat/exercise/lesson) | Tappable but < 48dp with no tooltip/label. |

### C. Loading / error / empty / offline
| # | Where | Defect |
|---|-------|--------|
| C1 | `diagnostic_screen.dart:257` | Bare spinner; `VaaniXLoadingIndicator` (branded, labelled) unused here. |
| C2 | `home_screen.dart` | Curriculum load failure degrades silently (generic card, no error strip). |
| C3 | `learn_screen.dart` error view | Retry is a bare OutlinedButton (design-system uses PrimaryButton), no live region; misleading "check your connection" copy for a bundled-asset failure. |
| C4 | `smart_practice_screen.dart` `_MaterialErrorCard` | No live region (TalkBack never announces AI failure). |
| C5 | `chat_screen.dart` error banner | Dismiss only — no Retry for the failed turn. |
| C6 | `lesson_content_screen.dart` empty-content | No action offered. |
| C7 | `achievements_screen.dart` | Unlock map load flashes all-locked before resolving. |

### D. Consistency / copy / motion
| # | Where | Defect |
|---|-------|--------|
| D1 | multiple screens | Retry CTA drift: 'Try again' / 'Try Again' / 'Retry'; 'Practise Again' vs 'Practice' spelling; heading case drift in onboarding/auth. |
| D2 | `exercise_screen.dart:770` | Sanskrit-specific hint `e.g. namaste` shown for every language's translation field. |
| D3 | `exercise_screen.dart:903` | Double space + hyphen-as-dash. |
| D4 | `splash_screen.dart` | 'Learn Sanskrit with Van' stale now that Learn ships 10 languages. |
| D5 | `exercise_screen.dart:953` (120ms) etc. | Motion outliers vs `AppMotion` (150/250/400/600); `AppMotion` referenced in exactly 1 file app-wide. |
| D6 | 8 sites | `BorderRadius.circular(999)` vs `AppDimens.radiusPill` token. |
| D7 | 5 sites | Raw route strings where `RouteNames` constants exist. |
| D8 | `learn_screen.dart:34-35` | Duplicate import (lint-level debt). |
| D9 | `learn_language_selection_screen.dart:98` | Hardcoded '10 languages' count. |
| D10 | `ob_goal_page.dart` | Trailing spaces in strings; missing terminal punctuation on one line; `min / day` vs `min/day` drift. |
| D11 | `chat_screen.dart:182-221` | Warning-amber small text on light tint ≈2:1 contrast; 10px/12px styles bypass the type scale. |
| D12 | `session_screen.dart:199` | Redundant ternary; unflexed stats row (overflow at large text scale). |
| D13 | `ob_subject_page.dart:89` | Empty `Text('')` placeholder leaving dead space. |
| D14 | `ob_nest_reveal_page.dart:209` | No-op tap makes VAN announce as a dead button. |

### E. VAN (audit result: architecture is strong — preserve)
- Rendering contract is correct: `BoxFit.contain` everywhere, canonical art never
  transformed, JSON↔Dart catalog parity tested, ticker pauses off-screen/background,
  reduced-motion honoured, cooldowns prevent spam, single-node semantics everywhere.
- **E1** `learn_screen.dart:200` uses `VanState.sad` (tired) for a system failure —
  `VanState.error` (confused/reassuring) is the correct context.
- **E2** `van_widget.dart:188-245` ticker rebuilds at 60fps even when static canonical
  art is shown (zero visual change) — battery/CPU waste on VAN-heavy screens.
- (Exam VAN states → B9.)

## 3. Reviewed and intentionally NOT changed (false positives / by design)

- Exam Mode bank fallback (`curriculumProvider ?? sanskritCurriculum`): Exam Mode is
  the Sanskrit exam by design — not a bug. Untouched beyond B8/B9.
- `Colors.white` on brand-primary fills across the app: correct in both themes.
- `ResponseCache` unused by `stream()`: real efficiency gap, but adding cache to the
  streaming path touches reliability-critical AI code that cannot be re-tested in this
  environment — documented as a future recommendation instead.
- Connectivity-aware fallback to the offline tutor in `adapterFor`: same reasoning;
  the offline tutor remains the unconfigured-key path exactly as shipped.
- VAN `darkMode` param on the fallback painter (unused in paint): cosmetic contract
  nit; documented, not churned.
- ALL-CAPS section eyebrows in smart practice vs shared `SectionHeader`: a deliberate
  accent style; not normalized.
- Splash dark-only background: intentional brand moment.
- Sentry `tracesSampleRate: 1.0`: ops decision, flagged for the founder, unchanged.
- 'Awards' short label on Home vs 'Achievements' screen title: intentional tile brevity.

## 4. Priority order for fixes

1. A1–A9 (production-critical defects), 2. A10–A11 + B1–B11 (language + a11y),
3. C1–C7 (states), 4. D1–D14 (consistency sweep), 5. E1–E2 (VAN), 6. docs +
CHANGELOG + regression tests where the fixed logic is pure-Dart testable.
