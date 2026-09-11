# Learn Mode 2.0 — M1 Architecture Foundation

Date: 2026-09-11
Status: COMPLETE (architecture spine delivered; behaviors staged for M2–M6)
Constraint compliance: no existing behavior destroyed; Exam Mode, VAN, AI
chat stack, XP/mastery/progress/streaks, onboarding/auth/signing and all
A–G content untouched. Flutter/Dart SDK unavailable in this sandbox —
validation was static (97 automated checks: delimiter balance across all
touched files, full import-graph resolution, symbol cross-references,
asset schema checks, byte-level preservation diff vs the M0 ZIP).
`flutter test` remains a user-machine step.

---

## 1. What M1 delivers

The Master Brief (§9) requires a clean conceptual separation:

```
Learner Profile → Diagnostic → Learning State → AI Planner →
Learning Session → Exercise Engine → Evaluation → Mastery →
Adaptive Replanning
```

M1 introduces that spine as TYPED, TESTABLE, PURE-DART modules beside the
existing engine — and fixes the single pre-existing wiring gap (G7) —
without replacing anything:

```
lib/features/learn/domain/spine/
├── mastery.dart               MasteryStage lifecycle + ConceptMastery
├── concept_graph.dart         Language→Skill→Concept graph (from curricula)
├── learning_state.dart        Evidence model + old→new derivation
├── learner_profile.dart       Intent model (goal/desired level/pace)
├── diagnostic.dart            Placement contract + friendly summaries
├── learning_plan.dart         Plans/activities/decisions + §14 validator
├── evaluation.dart            Session evaluation + mastery updates
├── learning_session.dart      Session/Outcome schemas
├── planner.dart               LearningPlanner contract + ValidatingPlanner
├── deterministic_planner.dart Offline planner (fallback chain anchor)
└── spine.dart                 Barrel

lib/features/learn/presentation/providers/spine_providers.dart
```

Every spine file is pure Dart (no Flutter imports) — unit-testable without
a widget binding, matching the project's domain-purity conventions.

## 2. The two learner-model halves

| Half | File | Question it answers | Milestone wiring |
|---|---|---|---|
| Intent (slow) | `learner_profile.dart` | "Where do you want to go, how, why?" | M2 persists (`learn_profile_<lang>_*`) |
| Evidence (fast) | `learning_state.dart` | "Where are you actually right now?" | M1 derives from existing progress data |

Splitting these keeps the M2 storage design simple and the M4 planner
prompt honest: intent without evidence = aspirations; evidence without
intent = raw telemetry; the planner needs both.

## 3. The concept graph — existing content, new eyes

`ConceptGraph.forCurriculum()` derives the §49 learning graph from the
ALREADY-SHIPPED curricula (no content rewrite, per §32 "map existing
content into the new system"):

- one `ConceptSkill` per chapter (chapter id = skill id — drift-proof);
- one `LearnConcept` per lesson, anchored to the trusted lesson id;
- prerequisites follow the curriculum's own pedagogical order (within a
  chapter each concept requires its predecessor; the first concept of a
  chapter requires the previous chapter's last concept) — A–G curricula
  are authored as ordered journeys, so this is the honest M1 mapping;
- empty/stub languages (kn/ml/or) produce an EMPTY graph — safe, never an
  error;
- unknown concepts fail CLOSED (`isUnlocked`, `conceptById`) so a
  hallucinating planner can never navigate outside trusted content.

M9 can enrich prerequisites with real linguistic knowledge later; the
derivation contract does not change.

## 4. The AI boundary (the heart of M1)

```
PlannerContext (structured learner state)   Master Brief §13
        │
        ▼
LearningPlanner  ── M1: DeterministicPlanner (offline, free, proven ladder)
        │              M4: GeminiPlanner (same interface, one-line swap)
        ▼
ValidatingPlanner  ── Master Brief §14 gate:
        │              · concept must exist in the trusted graph
        │              · language must match the active language
        │              · activity kind must be supported
        │              · difficulty 1..5
        │              · lesson anchor must be the concept's trusted content
        │            invalid activities dropped; nothing valid → fallback
        ▼
LearningPlan (grounded, language-safe, executable — or empty-but-valid)
```

Fallback chain (§36/§60): AI plan → deterministic plan → empty-but-valid.
Learn Mode can never crash, blank-screen, or hallucinate its way into
broken navigation. `PlannerDecision.fromRawJson` is deliberately defensive:
malformed AI output becomes a typed `PlannerRejection`, never an exception.

XP, streaks, mastery math stay local and deterministic (§61) — the planner
only ever PROPOSES educational next steps.

## 5. G7 fix — adaptive engine follows the active language

Before M1, `adaptiveNextActionProvider` / `weakLessonsProvider` /
`chapterBestFractionProvider` read the LEGACY Sanskrit curriculum and the
Sanskrit-only exercise map — so the Home CTA ignored the learner's chosen
language. After M1:

- they read `activeCurriculumProvider` (selected Learn language) and the
  language-dispatched exercise bank (`exercisesForLessonProvider`);
- no language selected → the active provider falls back to the legacy
  Sanskrit curriculum → pre-M1 behavior, byte-identical;
- a new `_chapterHasExam` guard prevents the engine from recommending a
  "Take the exam" for chapters that ship no exams (all Learn Mode
  languages), and makes `allDone` mean "every lesson done" for them.
  Sanskrit (every chapter has exams) is unaffected — its decision table is
  pinned by the pre-existing tests, which still pass;
- proof tests run the REAL provider chain with a persisted `hindi`
  selection against the real `hi.json` asset.

## 6. What deliberately did NOT land in M1

| Item | Lands in |
|---|---|
| Profile persistence (`learn_profile_<lang>_*` keys) | M2 |
| Diagnostic flow (VAN-led, adaptive difficulty) | M3 |
| Gemini planner behind `LearningPlanner` | M4 |
| AI content generation + validation | M5 |
| Session engine driving exercise kinds; review scheduling | M6 |
| Competency milestones; daily-goal loop | M7 |
| Personal path UI (Learn home) | M8 |
| Ten-language knowledge layer (H–J content) | M9 |
| Cross-language QA + AI failure matrix | M10–M11 |

The M1 models already carry the fields those milestones need (review
queue, mastery stages, session kinds, planner digest), so later milestones
EXTEND the spine instead of migrating it.

## 7. Preservation ledger (verified by byte-level diff vs M0 ZIP)

- Added: 11 spine domain files, 1 provider file, 6 test files, this doc.
- Modified: `progress/domain/adaptive.dart` (exam-existence guard),
  `progress/presentation/providers/adaptive_providers.dart` (active
  wiring), `test/.../adaptive_providers_test.dart` (settle new provider),
  `CHANGELOG.md` (M1 entry + removed the duplicated Part F section).
- Removed: nothing.
