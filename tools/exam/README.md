# VaaniX Exam Tools — Verification Mirrors

`verify_exam_m12.py` is the M12 FINAL QA + PRODUCTION FREEZE mirror
(1,968 checks): project identity (package name, app label, version
pin 2.0.0+2, applicationId, iOS display name), permissions (Android
INTERNET-only; iOS exactly the camera + photo-library strings),
assets (every pubspec dir exists; the 8 canonical syllabus files are
real and non-trivial; index lists all 7 courses), routing (every
RouteNames const registered; every pushNamed resolves — no dangling
routes), offline/AI honesty (the Gemini -> cached -> deterministic
never-throw chain, typed-first photo degradation, no persisted photo
bytes), a full secrets + hygiene sweep (no key literals, no
TODO/FIXME/HACK, no debug bypasses, no fake-AI flags, no print()
anywhere in lib/), curriculum honesty (pending = official
announcement status only), freeze hygiene, and the FULL regression
sweep M1->M11 re-run green.

```
python3 tools/exam/verify_exam_m12.py
```

Expected output: `M12 QA FREEZE: ALL GREEN — 1968/1968 checks
passed` (plus each milestone mirror printing its own green banner).

`verify_exam_m11.py` is the M11 divergence verifier (136 checks) for
the student-simulation harness `student_simulations.py`: journey
completeness for all nine personas (A-I), persona-specific behavior
fingerprints (D skips sessions, E edits scope, F retargets, G
overrides tasks unpunished, H keeps exactly one topic weak, I splits
by section), cross-persona path divergence (diagnostic accuracies,
mock bands, XP totals, plan task mixes, recovery counts, sessions,
weak findings all differ), determinism (two runs byte-identical),
and frozen-mirror parity (M8/M9/M10 stay green after import).

```
python3 tools/exam/student_simulations.py   # writes the M11 report
python3 tools/exam/verify_exam_m11.py
```

Expected output: `M11 MIRROR: ALL GREEN — 136/136 checks passed`.
The Dart-side companion is
`test/features/exam/simulation/student_journeys_test.dart` (run
`flutter test test/features/exam/simulation` on an SDK machine).

`verify_exam_m10.py` is the M10 invariant mirror (97 checks) for the
HOME + VAN + GAMIFICATION milestone: the XP tables are parsed FROM
the Dart source (so the mirror and the app can never drift), the hub
repository bounds/isolation/corruption/idempotence are asserted, the
snapshot derivation (today/continue/one-liners/VAN mood ladder) is
checked for every honesty case, and source-level wiring sweeps
verify the hub route, the smart gate, all five session controllers
feeding the gamification chain, and the XP strip on every finish
view.

```
python3 tools/exam/verify_exam_m10.py
```

Expected output: `M10 MIRROR: ALL GREEN — 97/97 checks passed`.

`verify_exam_m9.py` is the M9 invariant mirror: a 1:1 Python port of
the PYQ + mock stack (§25 provenance labels and filters, the grounded
PYQ bank built from official question patterns, the mini/section/full
mock ladder from official board structure, the DETERMINISTIC mock
analysis, both performance repositories, and the data-gated
weakPyq/weakMock weak-area signals) that runs WITHOUT a Flutter SDK
and asserts every master-plan invariant against the real canonical
syllabus JSONs (all 7 CBSE 2026-27 courses).

```
python3 tools/exam/verify_exam_m9.py
```

Expected output: `M9 MIRROR: ALL GREEN — 122/122 checks passed`.

What it enforces (master plan § references):
- §25    NOTHING generated is labeled an actual CBSE PYQ ("आधिकारिक
         CBSE" only on the empty official registry's label); pattern
         texts + marks verbatim from the official syllabus on all 7
         courses; filtering (section / pattern-kind / limit)
- §25/§41 mock structure from OFFICIAL data (80 marks / 3 hours board
         exam, per-section official marks; internal sections never
         mocked); analysis deterministic — same attempts, identical
         result; zero-attempt results never stored
- §21    pyqPerformance/mockPerformance evidence: weakPyq/weakMock
         fire ONLY with ≥2-attempt data; strong/too-thin evidence
         produces nothing; no data ⇒ M8-identical report
- §22    PYQ/mock findings flow into the recovery-day decision and
         the deterministic plan reserves the day (Student B journey)
- §30    no percentages in any student-facing string (source sweep)
- §12/§56/§41 repository bounds (60 topics / 40 results), per-track
         isolation, corrupt-JSON degradation, schema versions

`verify_exam_m8.py` is the M8 invariant mirror: a 1:1 Python port of
the weak-area stack (error intelligence §47/§21, weak-topic engine
§21, revision schedule §23, recovery-day engine §22, remediation
engine §22, both weak-area repositories, the amended planner +
validator, and the topic-filtered practice bank).

```
python3 tools/exam/verify_exam_m8.py
```

Expected output: `M8 MIRROR: ALL GREEN — 1124/1124 checks passed`.

What it enforces (master plan § references):
- §21    PATTERNS, not counts: repetition thresholds, misconception
         escalation (wrong-after-retry evidence required), singleton
         drops, per-topic isolation, PYQ/mock signals never emitted
         (M9 data required), §48 max-5 findings cap
- §22    recovery tiers + gap rules + no-back-to-back + honest floor;
         remediation phases with held-aside FRESH rechecks; recovered
         ⇔ clean recheck; planner reserves the decision's day (no
         brand-new material that day); rationale present (§50)
- §23    ladder math (expand/contract, floors/saturation), schedule
         seeding (mastered > strong; learning not scheduled),
         relearning re-entry, qualitative bands + same-day grace,
         reviewMix mistake-first + round-robin (never the original
         lesson's order)
- §26    uncertain evidence is never a student error
- §29/§30 severity vocabulary is qualitative; source-level sweep:
         NO percentages in any Devanagari student string; mirror↔Dart
         sentence parity
- §12/§56/§41 repository bounds (300-entry log, 100-outcome cap),
         per-track isolation, corrupt-JSON degradation, no empty
         entries
- §16/§9 every planner shape validates across 4 courses × 7 budgets
         (5–120 min) × 4 study-day patterns × 4 weak-area shapes;
         out-of-scope revision topics never become tasks
- §60    topic-filtered pools stay grounded (scope-wide distractors,
         the single-typed clamp fix)
- §M11   Student A / D / H end-to-end journeys (previews of the real
         student simulation milestone)

`verify_exam_m3_m7.py` is the M3–M7 invariant mirror: a 1:1 Python
port of the exam-profile / diagnostic / planner / practice /
evaluation logic.

```
python3 tools/exam/verify_exam_m3_m7.py
```

Expected output: `M3-M7 mirror: 1217 checks, 0 failed / ALL GREEN`.

What it enforces (master plan § references):
- §8/§9  profile anchors + budget bounds (5-min days are legal)
- §10    strong vs weak students get different qualitative reports
- §11    adaptive ladder: medium start, ±1 tier steps, never a cliff
- §16    hallucinated/out-of-scope plan topics are rejected
- §17    offline paths degrade to honest guidance, never "broken"
- §22    weak topics lead the deterministic plan
- §24    question types exist only where the course data supports them
- §26    unreadable/ambiguous/offline/timeout photos → UNCERTAIN +
         retake-or-type advice; confident extractions hit the rubric
- §27    rubric bands: correct / partial / uncertain / incorrect
- §29    mastery moves in the right direction with evidence
- §30    NO percentages in any student-facing string (global sweep)
- §33    scope revision change marks plans stale
- §60    every generated option string exists verbatim in syllabus data

The syllabus-layer tools (`tools/syllabus/`) cover M0–M2: data
validation, scope-selection invariants, and regeneration.
