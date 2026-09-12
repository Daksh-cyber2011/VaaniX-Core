# M12 — Final Polish + Learn Mode Freeze

**Status:** COMPLETE · **Milestone:** 12 of 12 · **Date:** 2026-09-11

## What this milestone is

The final pass before freezing Learn Mode 2.0 (Master Brief §93/§94).
No redesign, no new features — a closing sweep over the quality bar the
brief sets, two real accessibility gaps fixed, and the freeze
declaration with the full final report.

## The §93 polish checklist — audited state at freeze

| Area | State at freeze | Where pinned |
|---|---|---|
| UX | Learn Mode flows complete: language pick → profile → placement → path → lesson → practice → adaptive session → progress | M1–M8 docs; learn_navigation_test |
| Copy | honest, no jargon, no raw scores; placement speaks in friendly lines; session feedback encourages first | M3/M6 docs; diagnostic/session tests |
| Animations | only where already supported (VAN states, existing transitions) — nothing new added | VAN docs |
| Loading states | async curricula/plans render loading; never block callers | LearningPlanLike.empty contract (M1/M5) |
| Error states | AI chain degrades AI → cached → deterministic → empty-but-valid; honest unavailable reasons | M4/M10; ai_reliability_test |
| Empty states | exercise empty state, "curriculum on its way" for stub languages, empty-but-valid plans | exercise_empty_state_test, M9 |
| VAN feedback | reacts on quiz start/correct/wrong/finish, milestone unlock, streak, daily goal | M6/M7 docs |
| Progress | path UI + LEARNING MILESTONES + streak/daily goal strip | M7/M8 docs |
| XP | ledger unchanged (awardBonusXp idempotent; ms_/review bonuses) | M7 docs |
| Milestones | 9 competency milestones, evidence-driven | M7 docs |
| **Accessibility** | **2 real gaps fixed this milestone (below); everything else audited as already semantic** | §94 list below |
| Unicode | wrong-script guards, bidi/control rejection, ZWNJ/ZWJ allowed for Indic orthography | M9/M10 tests |
| RTL | Urdu is the only RTL language; Directionality wraps every content surface | M9 matrix test |
| Offline behavior | zero network required for the full Learn loop (deterministic planner + trusted content + local persistence) | M1/M6 docs |
| AI fallback | full §36/§60 chain re-validated per hop | M4/M10 tests |
| Performance | bounded queues (≤12), bounded prompts (256 KB cap, 30-event window, digest caps), bounded storage (7-day daily pruning) | M7/M10 docs |

## §94 accessibility — fixed in this milestone

Interactive state must never depend on colour alone. The audit found
the M6 session screen lagging behind the practice engine, which already
solved this:

1. **Choice options** (`session_screen.dart`): the post-answer
   "correct" state was conveyed by colour + an unlabeled check icon.
   Now each option is ONE semantics node — label carries
   `Option N: <text>` plus `, correct answer` after locking; the flags
   carry `selected`/`enabled`/`button`; `ExcludeSemantics` keeps the
   tree flat. This mirrors `exercise_screen`'s pinned pattern exactly.
2. **Matching tiles** (`session_screen.dart`): the "waiting for its
   match" state was colour-only. The tile now carries
   `selected: true` and the label
   `…, selected — now choose its match below`.

Everything else audited as already semantic (not touched, per §93 "do
not redesign"): exercise options + match tiles (existing Semantics),
learn path done/not-started icons (existing labels), progress meters
(labeled), diagnostic feedback (VAN speech + text), profile/language
pickers (existing Semantics), achievements/home/progress badges
(semantic labels). Existing accessibility work is preserved untouched.

## §95 Final Learn Mode Quality Bar — answered

- *Does the app actually understand where a new student is starting?*
  Yes — self-report seeds, the adaptive diagnostic measures without
  fabricating (M11 learner A places at level 0; B/C separate cleanly).
- *Can it skip unnecessary material if a skill is already good?*
  Yes — learner D's new learning starts past the fully mastered
  chapter, and no activity targets it (M11).
- *Does it notice a weak skill?* Yes — B's weak dimension is named and
  its concepts flow into reviews/repairs first (M11; M3).
- *Does Gemini create a sensible plan?* Structured, validated, and
  grounded — and when it fails, the deterministic planner produces the
  same class of plan (M4/M10/M11).
- *Does the plan change when the learner improves?* Yes — C's path
  advances and drops repairs after correct-heavy sessions (M11).
- *Does the app remember mastery?* Yes — derivation + evidence overlay,
  persisted per language, stage only rises (M1/M6).
- *Does it review forgotten concepts?* Yes — recentlyWeak/aging/
  maintenance scheduling with due dates (M6; learner E).
- *Are milestones meaningful?* Yes — competency evidence, not clicks
  (M7).
- *Does the learner know what to do next?* Yes — the path screen, the
  plan's next activity and VAN's next-action line (M8).
- *If Gemini fails, does the app remain usable?* Yes — proven across
  the full §90 matrix (M10).
- *If the learner chooses another language, does the same engine work?*
  Yes — 10/10 languages on the shared spine (M9).

## Freeze declaration

Learn Mode 2.0 is FROZEN at this milestone (M12, 2026-09-11). The
frozen deliverable is the complete replacement-ready project ZIP —
entire source, assets, curricula (A–J), tests, configuration and
documentation, no private secrets (§99). Further changes to
`lib/features/learn/**`, the shared spine, the language banks and the
Learn curricula should ship as a new versioned effort, not as edits to
this freeze. Exam Mode, VAN, AI chat, achievements and all signed
content remain exactly as shipped.

### Known issues at freeze (honest list)

- Dart/Flutter toolchain unavailable in the build environment: tests
  are hand-audited + mirrored in Python (M9–M11 method); run
  `flutter test` on a machine with the SDK for the formal green run.
- `docs/Learn-2.0/M7-*.md` was lost with the M7 regression; M7's scope
  is documented inside `M8-Restoration-Integration.md` and the
  CHANGELOG instead.
- Listening/comprehension stay unmeasured by the diagnostic (no audio
  exists — honest omission, per §11; §80/§81 remain future scope).
