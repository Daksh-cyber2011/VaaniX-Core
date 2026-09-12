# Exam Mode 2.0 — M10 + M11 + M12 Implementation

**Milestones:** M10 (HOME + VAN + GAMIFICATION integration), M11 (Real
student simulation), M12 (Final QA + production freeze)
**Date:** 2026-09-12
**Verification:** M10 mirror 97/97 · M11 mirror 136/136 · M12 QA freeze
1,968/1,968 (includes the full M1→M11 regression sweep) — all green.

---

## M10 — HOME + VAN + GAMIFICATION

The exam mode gets the cohesive home the master plan demands: today's
plan, continue, weak area, revision, PYQ, mock, XP, streak,
achievements, milestones and VAN context — every line derived from
REAL persisted state, never fabricated.

### Domain (pure Dart, no I/O)

- `lib/features/exam/domain/hub/exam_gamification.dart` —
  `ExamSessionXp`: deterministic, bounded, once-per-session XP for
  the six session kinds (diagnostic / practice / recovery / revision
  / PYQ / mock). XP is earned ONLY from finalized, persisted
  evidence; a session that crashed before persisting awards nothing.
  The award is keyed by a (kind, track, questions, verdicts)
  fingerprint so a re-rendered finish screen never re-awards.
  `ExamSessionRecord` / `ExamSessionOutcome` carry the honest
  outcome line (+XP, streak state, real unlocks).
- `lib/features/exam/domain/hub/exam_hub_models.dart` — the hub
  snapshot derivation: which plan day is "today", the CONTINUE
  target, honest one-liners for weak areas (§21), revision (§23),
  PYQ/mock (M9), the readiness countdown, and the VAN mood/message
  ladder (`ExamHubVanMood` welcome/focus/care/celebrate). With no
  data the snapshot says so — "no plan yet", "no mock yet".

### Data + providers

- `lib/features/exam/data/hub/exam_hub_repository.dart` — the small
  persisted state the home needs on top of the other milestones:
  per-track day completions (which plan task types actually finished
  per calendar day — §20 freedom preserved, the plan stays a
  recommendation) and the session XP ledger (once-ever awards,
  mirroring the app-wide `awardBonusXp` ids). One versioned JSON
  document per concern; corrupt data degrades to empty (§41/§57);
  day keys bounded (§56); track-isolated (§38).
- `exam_gamification_providers.dart` — the chain that runs when any
  exam session finishes: persist attempts → update mastery → mark
  the plan task done → award XP once → dispatch VAN reactions +
  app-wide streak/achievement events. Wired into ALL five session
  controllers (diagnostic, practice, weak-area, PYQ, mock) at their
  real finish points.
- `exam_hub_providers.dart` — gathers the real state (plan, profile,
  weak-area overview, PYQ/mock history, today's completions) and
  feeds the pure snapshot.

### UI

- `exam_hub_screen.dart` — the hub itself: today's plan rows with
  real check-marks, the CONTINUE card, one-tap weak-area/revision/
  PYQ/mock cards with live state lines, XP/level/streak from the
  same providers the Nest uses, and VAN's speech strip with mood.
  Degrades honestly: no plan → a build-plan CTA (never a fake day).
- `exam_xp_strip.dart` — the compact honest outcome line
  ("+12 XP · 3-day streak") rendered on every session finish screen
  (diagnostic, practice, weak-area, PYQ, mock). Hidden when nothing
  happened.
- Route `/exam/hub/:trackId`; the exam screen's Board-Prep gate now
  lands on the hub; all five session screens deep-link back.

### Verification

`tools/exam/verify_exam_m10.py` — 97 checks: XP constants parsed
FROM the Dart source (drift impossible), repository bounds/
isolation/corruption/idempotence, the snapshot derivation for every
VAN-mood and honesty case (mirrored 1:1 from the Dart test suite),
and source-level wiring checks (route registered, gate lands on the
hub, all five controllers feed the chain, the strip renders on every
finish view, VAN events dispatched with honest payloads).

---

## M11 — REAL STUDENT SIMULATION

Nine personas from the master plan, each walking the FULL journey
through the SAME verified engine ports the shipped Dart code encodes:

> diagnostic → plan → daily sessions → mistakes → replanning →
> weak-area day → revision → PYQ → mock → readiness + XP

| Persona | Behavior | Fingerprint |
|---|---|---|
| A | strong student | diag 1.00, 0 weak topics, mock strong, top XP |
| B | average student | diag 0.40, balanced mix, mock strong |
| C | weak student | diag 0.10, 13 needs-attention topics, mock needsAttention |
| D | skips sessions | 8 skipped days, fewest sessions/revisions |
| E | changes syllabus scope | scopeRevision 2, "scope edited" replan, narrower final plan |
| F | changes readiness target | anchor moved 56→21 days, forced rebuild |
| G | chooses different tasks | 132 PYQ vs 6, top XP, never punished (§20) |
| H | repeatedly fails one topic | the topic stays the §22 focus; one-topic weakness ≠ global |
| I | strong one section, weak another | mastery + findings split by section, weakMock section-honest |

### Deliverables

- `tools/exam/student_simulations.py` — the 21-day × 9-persona
  harness (deterministic seeded LCG; byte-identical re-runs) on the
  real canonical syllabus JSONs. Journeys exercise the frozen M4/M5/
  M6/M8/M9/M10 engine ports. Writes
  `docs/Exam-2.0/M11-Student-Simulations.md`.
- `tools/exam/verify_exam_m11.py` — 136 checks: journey completeness
  per persona, persona-specific fingerprints (D/E/F/G/H/I behaviors
  asserted explicitly), cross-persona path divergence (diagnostic
  accuracies ≥ 6 distinct, mock bands 3 distinct, XP all 9 distinct,
  task mixes/recovery counts/sessions/weak findings all diverging),
  engine honesty (determinism, frozen mirrors still green after
  import), §16/§9 plan validation, XP once-per-session.
- `test/features/exam/simulation/student_journeys_test.dart` — the
  Dart-side proof: the same nine personas through the REAL Dart
  engine classes (ExamDiagnosticEngine, DeterministicExamPlanner,
  PracticeContentBank, WeakAreaEngine, WeakAreaDayEngine,
  RevisionEngine, PyqBank, MockEngine, ExamSessionXp) with the same
  divergence assertions. Runs with `flutter test` on an SDK machine.

### Fixes made while completing the harness (this session)

The prior session left the harness mid-build; completing it surfaced
and fixed six real issues: the `review_mix` / `build_remediation` /
PYQ-bank / mock-result API mismatches against the frozen mirrors,
the section-keyed mock pool (silently empty before), a severity
vocabulary drift (`developing` never existed in the §21 ladder — the
real M9 `build_report_m9` port is now used), plan-reserved recovery
days not being counted, F's target change mutating the wrong dict,
and `mastery_bands` mapping a stale stage vocabulary (strong/
needsAttention topics were silently counted as "learning").

---

## M12 — FINAL QA + PRODUCTION FREEZE

`tools/exam/verify_exam_m12.py` — 1,968 checks, ALL GREEN:

- **Identity:** package `vaanix_app`, Android `com.vaanix.app` +
  label "VaaniX", iOS display name, version pinned **2.0.0+2** (the
  Exam Mode 2.0 freeze version — bumped from 1.0.0+1).
- **Permissions:** Android requests INTERNET only; iOS carries
  exactly the camera + photo-library usage strings the M7 photo flow
  needs (and nothing else).
- **Assets:** every pubspec asset dir exists; all 8 canonical
  syllabus files parse with real structure (≥ 100 items total,
  80-mark board totals); index lists all 7 courses; web manifest +
  icons present.
- **Routing:** every `RouteNames` const registered in the router;
  every `pushNamed` in lib/ resolves to a declared name (no
  dangling routes).
- **Offline / AI honesty:** connectivity service + offline banner
  wired; exam planner chain Gemini → cached → deterministic
  (never-throw); vision evaluator degrades to typed-first with §26
  advice; photo bytes never persisted; unconfigured keys ⇒ honest
  offline mode (no fake AI).
- **Secrets/hygiene:** no key literals anywhere (AIza/sk-/JWT/anon
  patterns swept over all of lib/); credentials flow through dotenv
  + AppEnvironment only; the shipped `.env` is empty (`.gitkeep`);
  no TODO/FIXME/HACK, no debug bypasses, no fake-AI flags, no
  `print()` anywhere in lib/ or the exam feature.
- **Curriculum honesty:** no placeholder syllabus — `pending`
  appears only as the honest official-announcement status, never as
  a fabricated substitute for content.
- **Freeze hygiene:** `.git` preserved; no build artifacts in the
  project tree.
- **Regressions:** M1 432/432, M2 124/124, M3–M7 1217/1217,
  M8 1124/1124, M9 122/122, M10 97/97, M11 136/136 — plus Dart test
  directories present for every milestone.

### Honest environment limitation (documented hand-off)

This build environment has no Flutter SDK, so the following must run
on a machine with the toolchain (all Dart-side prerequisites are
already in place — 22/22 M10-M12 files syntax-clean, all engine
mirrors green):

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release   # if the environment supports it
```

No secrets, no debug credentials, no hard-coded API keys, no
temporary development bypasses, no fake AI, no placeholder
curriculum — verified by sweep, not by assertion.
