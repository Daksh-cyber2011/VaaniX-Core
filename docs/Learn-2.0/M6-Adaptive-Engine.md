# M6 — Adaptive Exercise Engine

**Status:** COMPLETE · **Milestone:** 6 of 12 · **Date:** 2026-09-11

## What this milestone is

The exercise engine stops being a flat queue. It now understands all SIX
activity kinds the planner emits — `newLearning`, `practice`, `review`,
`weakRepair`, `masteryCheck`, `challenge` — and adapts live while the
learner answers (Master Brief §18):

> If a learner repeatedly gets something correct: reduce repetition.
> If a learner repeatedly gets something wrong: identify the underlying
> concept. Then: prerequisite → explanation → easier exercise → guided
> exercise → normal exercise → mastery check. Do not merely repeat the
> same question.

It also completes the mastery loop M1 typed but left undriven: sessions
EARN the upper ladder stages (§19) and schedule practical reviews (§20),
so the spine's `LearningState` finally reflects recall, application,
mastery and maintenance — all from real session evidence, never
fabricated.

## The adaptive session engine (`spine/session_engine.dart`)

- **All six kinds, shaped differently** (one engine, per-kind policy):
  newLearning visits 1 exercise per concept (light — the lesson teaches),
  practice/review/weakRepair visit 2, challenge visits 3 (harder knob,
  no support beats), masteryCheck visits 3 strict probes. Review and
  weak-repair sessions put the persisted review-queue concepts FIRST.
- **Reduce repetition:** two consecutive first-try correct answers on a
  concept TRIM the remaining same-concept steps (same or easier
  presentation) and the session advances — repetition is never padded.
- **The §18 ladder on repeated failure:** two consecutive wrong answers
  on a concept rebuild it step by step — a PREREQUISITE exercise (when
  the trusted graph offers one), a TRUSTED EXPLANATION beat (lesson
  reference text from the M5 registry), an EASIER exercise (a validated
  AI-generated variant from the M5 cache when one exists, else another
  trusted exercise), then a GUIDED exercise (same concept, a DIFFERENT
  exercise, hint surfaced). The ladder runs at most once per concept per
  session — a hopeless concept can never loop. A mastery check is never
  inserted mid-session; it is its own session kind.
- **Never the same question twice:** asked + reserved id sets make
  repeats impossible, including between ladder rungs.
- **Budget honesty:** support beats never consume the exercise budget;
  exercise steps beyond the budget are dropped (remediation can still
  explain, it just stops asking).
- **Evaluation edge:** `buildEvaluation()` produces the M1
  `EvaluationResult` (per-concept `correct / attempts / firstTryCorrect`)
  — the Plan → Session → Evaluation contract from the M1 spine.

## Mastery scheduling (`spine/mastery_scheduling.dart`)

- **Stage uplift gates (§19):** evidence can only RAISE a stage, and
  every upper rung has its own evidence kind:
  - `review` session, correct first-try, learned material → `recalled`
    (a mastered concept that recalls correctly → `maintained`);
  - `challenge` session, correct first-try → `applied`;
  - `masteryCheck` passed (first-try accuracy ≥ 0.8 across ≥ 2 probes)
    on understood material → `mastered`;
  - practice/newLearning/weakRepair build evidence (counts, strength)
    but never uplift stages on their own.
  A concept that was never learned can never be "recalled" — the gates
  require prior evidence (`practiced+`).
- **Practical review policy (§20 — deliberately simple):** a missed
  concept → `recentlyWeak`, due in 1 day, high priority; a correct but
  aging concept (`practiced+`, last practised ≥ 3 days ago) →
  `agingStrong`, due in 3 days; a mastered concept → `maintenance`, due
  in 7 days. Fresh correct answers fabricate nothing.
- **Evidence overlay:** persisted session evidence merges onto the M1
  derived state with a never-lower guarantee — derivation stays
  authoritative for progress-backed stages and counters; evidence only
  adds upper stages, recency and due dates. Evidence for a
  lesson-not-completed concept is kept honestly (e.g. a passed mastery
  check), with conservative strength.

## Live wiring

- `spine_providers.dart`: `activeLearningStateProvider` now overlays the
  persisted evidence masteries (extras channel M3 opened) — no new
  storage, no migration, additive only.
- `session_providers.dart`: `AdaptiveSessionController` resolves trusted
  pools (+ cached M5 generated variants as easier/guided material — ZERO
  AI calls, personalization stays learner-triggered), drives the engine,
  and on finish runs the persist-first pipeline: evidence masteries +
  review queue + performance events → `learn_profile_<iso>_state`
  (same namespace, same corruption contract, prefix reset covers it),
  trusted-exercise mastery through the EXISTING idempotent progress
  path, then watched-provider invalidation so the spine rebuilds.
  Generated `gen-` exercises NEVER write progress — only trusted bank
  ids are recorded.
- `session_screen.dart` (`/learn/session`): the guided session runner —
  all five engine types render, ladder rungs are honestly labelled
  (Warm-up / Foundations / Easier step / Guided step / Refresher),
  AI-made rungs carry a "Made for you · AI" badge, feedback beats are
  encourage-first (§44), the finish view is friendly (no raw jargon) and
  the footer is honest: sessions tune VAN's path; lesson XP and streaks
  still live in lessons.
- Smart Practice's focus card gained a **Start guided session** entry —
  the same plan activity, run through the adaptive engine.

## Preserved

Everything. The legacy practice flow (`ExerciseNotifier`, exercise
screen, XP path), Exam Mode, VAN, AI chat, achievements, the A–G
curricula, the M1–M5 spine contracts — untouched. The M5 screen's
`VanState.confused` reference (a compile-breaking typo that slipped
past static checks) is fixed to `VanState.caring`.

## Validation

- 6 new test files: engine (ladder, trimming, six-kind shaping,
  no-repeat, budget, evaluation, real-bank parity), scheduling (uplift
  gates, review policy, queue merge/cap, overlay), providers
  (persistence, spine pickup, honest unavailable states, mastery-check
  uplift), widget flow (real UI answers → finish), plus the M5 suite.
- `scripts/m6_validate.py`: delimiter balance, import resolution,
  symbol pins, asset sanity, and the byte-level preservation diff vs
  the M5 ZIP (added files all M6; changed files allow-listed).
- Flutter/Dart SDK unavailable in the sandbox; `flutter test` remains a
  user-machine step, as in M1–M5.
