# Learn Mode 2.0 — M2 Learner Profile + Goal System

Date: 2026-09-11
Status: COMPLETE
Constraint compliance: additive only — the global UserProfile (name,
companion, personality, streak) is untouched; every other feature module
unchanged except the Learn screen's AppBar/body (one action + one optional
prompt card) and the router (one nested route). Flutter/Dart SDK remains
unavailable in this sandbox; validation was static (delimiter balance,
import resolution, symbol cross-references, byte-level preservation diff
vs the M1 ZIP with an explicit allow-list). `flutter test` remains a
user-machine step.

---

## 1. What M2 delivers

Master Brief §10: a real learner model. M2 makes the M1 spine LIVE:

- **Persistence** — `LearnProfileRepository`
  (`lib/features/learn/data/learn_profile_repository.dart`):
  - `learn_profile_<iso>` → `LearnerProfile` JSON (goal, desired level,
    pace, practice style, self-report, daily goal minutes, …)
  - `learn_profile_<iso>_state` → `LearningState` extras JSON (review
    queue + recent performance; the slots M3/M6 fill)
  - corruption-safe: missing / malformed / wrong-language values degrade
    to "unset", never crash; `clearAll()` is prefix-scoped so a profile
    reset can never touch Exam Mode or progress keys.

- **Wiring** — `learn_profile_providers.dart`:
  - `learnerProfileProvider(language)` — per-language notifier;
    persist-FIRST-then-publish (the progress module's hard-learned
    lesson), idempotent no-op saves;
  - `learnerProfileConfiguredProvider(language)` — "has the learner
    actually personalized this language?" (drives the Learn screen
    prompt);
  - `activeLearnerProfileProvider` — profile of the selected language,
    null on the legacy Sanskrit path.

- **Planner integration** — `activePlannerContextProvider` now carries
  the profile; session sizing follows the learner's own daily-goal
  minutes; `PlannerContext.toStructuredDigest()` exposes goal / desired
  level / pace / minutes as pure data for M4's prompt assembly.

- **UI** — `LearnProfileScreen` at `/learn/profile`:
  - five sections in the VaaniX design language (same card-tile
    affordances as the language picker, VAN intro, calm captions):
    self-report → goal → desired level → pace → practice style → daily
    goal chips;
  - ONE explicit save (partial edits never leak into planning); reset to
    defaults; safe empty state without a language;
  - entry points: Learn-screen AppBar action (tune icon, per-language) +
    a dismissable "Make it yours" prompt card that disappears once a
    profile is saved.

- **Self-report (new spine field)** — `SelfReport` enum
  (`almostNothing / recognizeScript / understandBasics / conversational`)
  with a coarse `suggestedLevel` hint. It deliberately is NOT a level
  selector (Master Brief §11): it seeds the M3 diagnostic's starting
  difficulty and the pre-diagnostic planner default. Backward-compatible
  JSON: pre-M2 profiles without the field load unchanged.

## 2. Brief-compliance notes

- §28 goals: all eight options (general, conversation, reading, writing,
  travel, school, culture, mastery) — pinned by test.
- §29 desired levels: Starter → Advanced with clearly-labelled internal
  names, explicit "not a formal certificate" caption — no CEFR claims.
- §58 daily goal: minutes preference stored now; the measurement loop
  that counts REAL learning actions against it lands in M7 (audit gap
  G9). Opening the app will never count as learning.
- §35 privacy: learning data only; local-only store; per-language keys
  prevent cross-language bleed; nothing user-identifying.
- §10 "system must not force everyone into the same path": the profile
  is optional — defaults are honest, the planner treats a missing
  profile as "not yet diagnosed".

## 3. What deliberately did NOT land in M2

| Item | Lands in |
|---|---|
| Self-report seeding the diagnostic difficulty | M3 |
| Review-queue/recent-performance writers (state extras) | M3 / M6 |
| Daily-goal measurement loop | M7 |
| Gemini prompt consumption of the digest | M4 |

## 4. Preservation ledger (byte-level diff vs M1 ZIP)

- Added: repository, providers, screen, 5 test files, this doc.
- Modified: `spine/learner_profile.dart` (additive SelfReport field),
  `spine_providers.dart` (context wiring), `learn_screen.dart` (AppBar
  action + optional prompt card), `app_router.dart` + `route_names.dart`
  (one nested route), `CHANGELOG.md`.
- Removed: nothing.
