# M11 — End-to-End Learner Simulation

**Status:** COMPLETE · **Milestone:** 11 of 12 · **Date:** 2026-09-11

## What this milestone is

The proof milestone (Master Brief §91/§92). Instead of testing engines
in isolation (M1–M10 already pin each one), M11 drives COMPLETE learner
journeys — onboarding → diagnostic → plan → lesson → exercise →
mistakes → mastery → review → replanning — through the REAL spine and
the REAL trusted data, for five distinct personas, and demonstrates the
one thing the whole project exists for:

> Two learners choosing the SAME language receive DIFFERENT learning
> paths because their current levels, strengths, weaknesses, goals and
> mastery are different. (§92)

## The harness

`test/features/learn/simulation/e2e_learner_simulation_test.dart`

- REAL under test: `ConceptGraph`, `DiagnosticItemBank`,
  `DiagnosticEngine`, `deriveLearningState`, `applyMasteryEvidence`,
  `DeterministicPlanner` behind the `ValidatingPlanner` facade,
  `AdaptiveSessionEngine` (including the full §18 ladder),
  the M6 mastery scheduling (`evidenceFromRecords`,
  `buildEvidenceMasteries`, `scheduleReviewUpdates`,
  `mergeReviewQueue`), `TrustedContentRegistry`, and the shipped Hindi
  curriculum asset + the shipped Hindi exercise bank (20 lessons, 69
  exercises).
- SIMULATED (thin, documented mirrors of the provider finish pipelines
  that M3/M6 tests already pin): the diagnostic finish (extras
  seeding), lesson completion + first-try practice mastery recording,
  and the persist-first session finish.
- Deterministic: every run pins its seed; the file doubles as a
  regression canary for the whole adaptive pipeline.

## The five §91 journeys (all on real Hindi data)

| Learner | Start state | What the simulation proves |
|---|---|---|
| A — complete beginner | `almostNothing`, empty state | all-wrong placement lands at level 0; after a mistake-heavy first session the replanned path opens with `weakRepair` on the struggled concept — **the path changed because of the mistakes** |
| B — vocabulary OK, grammar weak | `understandBasics`, empty state | the diagnostic names **grammar** as the weak dimension and the seeded reviews surface in the plan — every review target is a grammar-chapter concept |
| C — strong beginner → intermediate | `conversational`, 20 min/day | placement separates C (level 4) from A (level 0); correct-heavy work earns `applied` (challenge) then `mastered` (check), and the replanned path **advances forward** — never repeats done work, nothing left to repair |
| D — advanced in one skill, weak in another | full script chapter mastered, half-done grammar chapter | the plan repairs the weak skill FIRST, new learning **skips the mastered chapter entirely** (starts at chapter 2+), and no activity targets chapter-1 material |
| E — returning after a break | two chapters done ~10 days ago, one unfinished lesson, stale queue | the plan opens with a refresher, the queue surfaces due reviews, new learning resumes where E actually stopped, and a correct review keeps mastered material `maintained` |

The §18 ladder is additionally pinned rung-by-rung on real bank data
(`hi_grammar_postpositions`, 4 exercises, prerequisite
`hi_grammar_gender` with 4): two wrong answers produce
prerequisite → explanation beat → easier → guided, the same exercise
is never asked twice, and the wrong streak schedules a SOON review.

## §92 CRITICAL DEMONSTRATION

Learner A and learner D pick the same language (Hindi):

- A's plan: `[review, review, newLearning]` starting at the very first
  concept.
- D's plan: `[weakRepair, weakRepair, review, review, newLearning,
  practice]` starting at chapter 2.

The kinds differ, the new-learning concept differs, and every
difference traces to a state difference: A has no mastery records (so
nothing to repair and nothing to skip), D has chapter-1 mastery (so
that material is skipped) and a started-but-unmastered grammar concept
(so it is repaired first). This is the proof that Learn Mode is
adaptive.

## Verified honestly

- The Dart suite is hand-audited line-by-line against the real engine
  APIs (this environment has no Flutter toolchain — see the M7/M8/M9/M10
  docs for the same caveat and method).
- `scripts/verify_m11_simulation.py` is a runnable Python mirror of the
  pure spine rules (line-referenced to the Dart sources). It executes
  the SAME five personas + §92 proof + ladder transcript + determinism
  canary against the SAME real data: **ALL CHECKS PASSED** (34 checks).
  It also caught and corrected two scenario-design errors before the
  freeze: a challenge can never uplift an already-mastered concept
  (stages only rise — the §19 order is challenge first, check second),
  and a returning-learner prior must respect the prerequisite ladder
  (script → greetings → daily).
