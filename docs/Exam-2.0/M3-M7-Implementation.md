# Exam Mode 2.0 — M3–M7 Implementation Report

**Date:** 2026-09-12 · **Status:** Complete · **Verification:** 1217/1217 mirror checks green, 57 Dart files syntax-clean

This report documents milestones M3–M7 of the Exam Mode 2.0 master
plan, delivered as one combined build (the user's m3+m4, m5+m6 and m7
instructions). Everything below is **additive** to the existing app —
Learn Mode, the legacy quiz, VAN, gamification and all their tests are
untouched except for two compile fixes in M2 screens (see §6).

---

## 1. M3 — Exam Profile (master plan §8, §9, §12)

**Files**
- `lib/features/exam/domain/exam_profile.dart`
- `lib/features/exam/data/exam_profile_repository.dart`
- `lib/features/exam/presentation/providers/exam_profile_providers.dart`
- `lib/features/exam/presentation/screens/exam_profile_screen.dart`

**Design decisions**
- The primary question is *"by when do you want to be exam-ready?"*
  (§8), never "when is your exam". Readiness is a target DATE
  (primary anchor), a duration in WEEKS (option B), or both — with
  date winning when both exist. The actual exam date is optional and
  secondary.
- Available time (§9) is what the STUDENT declares: 5 min/day is as
  valid as 2 h/day, the UI never suggests studying more, and the
  weekly budget is `dailyMinutes × studyDays`.
- Validation is total: bounds (5..480 min, 1..7 days, 1..52 weeks),
  past-date rejection, anchor-required, exam-date-after-readiness.
  Invalid profiles are refused at the repository — the store can only
  contain planning-grade data.
- Migration safety (§57): `schemaVersion` on the JSON, defensive
  `fromJson` (bad dates → null, bad numbers → defaults, unknown enum →
  default), corrupt entries skipped without crashing.

**Flow wiring:** scope summary confirm → Exam Profile → save chains
into the diagnostic. Re-entry: the exam tab's Board-Prep card routes
here when a scope exists but no profile does.

## 2. M4 — Adaptive Diagnostic (§10, §11)

**Files**
- `lib/features/exam/domain/diagnostic/exam_diagnostic_models.dart`
- `lib/features/exam/domain/diagnostic/exam_diagnostic_engine.dart`
- `lib/features/exam/data/diagnostic/diagnostic_item_bank.dart`
- `lib/features/exam/domain/exam_learner_profile.dart`
- `lib/features/exam/data/exam_learner_profile_repository.dart`
- `lib/features/exam/presentation/providers/exam_diagnostic_providers.dart`
- `lib/features/exam/presentation/screens/exam_diagnostic_screen.dart`

**Design decisions**
- 5–10 minute "VaaniX challenge" (max 10 items, hard-bounded
  5..15 by an assert), never a boring exam.
- Adaptive ladder (§11): starts MEDIUM for everyone; correct → harder
  (max tier 3), wrong/skip → easier (min tier 1). Topic selection is
  coverage-first (least-probed topics first) so 10 questions span the
  syllabus instead of hammering one chapter.
- **Question grounding (§60):** every question is generated
  deterministically from the canonical syllabus JSON — section
  membership, sub-topic membership (official `details` lists), marks
  awareness, chapter identity. No invented strings: the mirror
  asserts every option exists verbatim in syllabus data.
- Report (§10): per-topic qualitative bands
  (strong/learning/needsAttention) + observation sentences like
  "ध्यान चाहिए: सन्धिकार्यम् — योजना इनसे शुरू होगी।" **No
  percentages anywhere (§30).**
- Learner exam profile (§12): persistent per track, EWMA topic
  strength (α 0.4), §29 stage ladder with the exact student-facing
  vocabulary (Learning/Practicing/Strong/Mastered/Needs Review/Needs
  Attention), weak-first ordering consumed by the M5/M6 engines.
- Ability math: difficulty-weighted accuracy (easy 1.0 / medium 1.2 /
  hard 1.5) — engine-only numbers, never surfaced.

**Bug fixed by the mirror:** the first build had a hard→easy fallback
cliff when a tier pool emptied (3→1 jumps). The engine now falls back
through NEAREST tiers only, and starts at the nearest LOWER tier when
a course has no medium pool at all (all Hindi tracks).

## 3. M5 — AI Planner Engine (§13–§18)

**Files**
- `lib/features/exam/domain/planner/exam_plan_models.dart`
- `lib/features/exam/domain/planner/exam_plan_validator.dart`
- `lib/features/exam/data/planner/gemini_exam_planner.dart`
- `lib/features/exam/data/planner/deterministic_exam_planner.dart`
- `lib/features/exam/data/planner/exam_plan_repository.dart`
- `lib/features/exam/presentation/providers/exam_plan_providers.dart`
- `lib/features/exam/presentation/screens/exam_plan_screen.dart`

**Design decisions**
- Gemini is an intelligence layer, never the source of truth (§14).
  Its output passes the SAME validator as everything else: tasks must
  reference real selected topicIds, every day must fit the student's
  budget, days are 1..7 with a learn/practice backbone, task minutes
  1..90. Hallucinated topics and over-budget days are rejected and the
  chain falls back.
- The §17 fallback chain is wired in the provider: **Gemini → cached
  plan (fresh + same scope revision) → deterministic planner**. Every
  accepted plan is cached (write-through). The UI honestly labels the
  source (AI योजना / सहेजी गई योजना / ऑफ़लाइन योजना).
- The Gemini planner reuses the Learn Mode M4 planner's
  `PlannerTextClient` interface and its shared 15-RPM rate-limit budget
  (§18: one app-wide budget) — extend, don't duplicate (§53).
- Deterministic floor: weak topics first (§22), then official marks
  weight (grounded priority), interleaved learn/practice/review, one
  PYQ slot mid-window and a mock slot late. Task sizes fit the budget:
  a 5-min/day student gets 5-min tasks (the plan can never overflow
  §9).
- Replanning (§33): the M2 scope revision counter is the trigger — a
  cached plan whose `scopeRevision` ≠ current revision is stale and
  never served.

**Bugs fixed by the mirror:** 10-minute tasks inside 5-minute budgets
(§9 violation), and empty trailing days when studyDaysPerWeek < 7
(plan days now = study days exactly, day 0 = today always).

## 4. M6 — Learning + Practice Loop (§19, §24, §28, §29)

**Files**
- `lib/features/exam/domain/practice/practice_models.dart`
- `lib/features/exam/domain/practice/practice_session_engine.dart`
- `lib/features/exam/data/practice/practice_content_bank.dart`
- `lib/features/exam/presentation/providers/exam_practice_providers.dart`
- `lib/features/exam/presentation/screens/exam_practice_screen.dart`

**Design decisions**
- The loop is a state machine: **answer → §28 feedback (always shown)
  → ONE invited retry → reveal + advance → summary**. The final
  attempt is recorded only on advance (`awaitingNext`), so feedback is
  never skipped and mastery evidence is exact.
- Feedback (§28): specific and constructive — names the missed rubric
  point ("बस विसर्गसन्धिः वाला बिंदु छूट गया"), never just "Wrong.",
  never shame; closing summary is honest at every score level.
- Question types (§24): MCQ + typed short answer, offered exactly
  where the course data supports them (Sanskrit tracks have rich
  official sub-topics; Hindi tracks run MCQ-first). No type is forced
  onto any subject.
- Content grounding: accepted answers are official topic titles,
  rubric points are official sub-topics — the same trusted-content
  discipline as the diagnostic (§15/§60).
- Mastery connection (§29): every finalized attempt updates the
  persistent learner profile; correct/partial strengthen the topic,
  misses/reveals re-enter it into the weak set that drives the next
  plan and the next session's question order.

**Bug fixed by the mirror:** typed questions were crowded out of the
session by the larger MCQ pool; typed questions now reserve ≥ a third
of the session when the data supports them.

## 5. M7 — Answer Evaluation (§26, §27, §28, §30) — the headline milestone

**Files**
- `lib/features/exam/domain/evaluation/answer_models.dart`
- `lib/features/exam/domain/evaluation/answer_normalizer.dart`
- `lib/features/exam/domain/evaluation/rubric_evaluator.dart`
- `lib/features/exam/data/evaluation/gemini_vision_evaluator.dart`
- `lib/features/exam/data/evaluation/evaluation_repository.dart`
- UI: the practice screen's answer input + feedback panel
- Platform: `image_picker` dependency, iOS camera/photo usage strings

**Typed answers — rubric, not keywords (§27)**
- Evaluation has two dimensions: accepted-answer **coverage**
  (normalized token overlap vs every official accepted phrasing) and
  required-point **completeness** (each rubric point matched at ≥0.7
  coverage).
- Thresholds: ≥0.8 correct · ≥0.5 partially correct · 0.35–0.5 with
  mixed evidence **uncertain** (never a guess). Full answer + missed
  points → partially correct.
- Normalizer: danda/॥ stripping, Devanagari digit folding (०–९),
  nukta/chandrabindu/ळ folds, zero-width OCR leftovers, Latin case,
  whitespace/punctuation — a correct answer matches however the
  student writes it (danda, spacing, mixed digits).

**Photo answers — honest OCR (§26)**
- Gate 1 (pre-network, zero cost): tiny files and extreme aspect
  ratios rejected with retake advice.
- Gate 2: offline/unconfigured → typed-first guidance — never "AI
  failed, app broken" (§17).
- Gate 3: Gemini vision extraction (inline image part, 20 s timeout,
  shared rate limiter, temperature 0, strict-JSON verdict).
- Gate 4: unreadable or low-confidence extraction → **UNCERTAIN** with
  "retake or type" advice; the extracted text is surfaced so the
  student can verify.
- Confident extraction flows into the SAME rubric evaluator as typed
  answers — deterministic structures control scoring (§14/§27).
- Confidence is a qualitative band (low/medium/high) rendered as
  पक्की/ठीक-ठाक/कम — **never a percentage (§30)**.
- Privacy: photo bytes are transient inputs — only compact verdict
  records are persisted (bounded at 200/track, §56).

## 6. Fixed — pre-existing M2 bugs

- `VanState.celebrating` (nonexistent enum value, would not compile)
  in `exam_scope_selection_screen.dart` and
  `exam_scope_summary_screen.dart` → `VanState.achievement`.

## 7. Verification

- `tools/exam/verify_exam_m3_m7.py` — **1217/1217 checks green**
  against all 7 canonical course files. Mirrors the Dart logic
  (thresholds, weights, ladders, budgets, banks) and asserts: §8
  anchors, §9 budget fits at 5/15/30/45/120 min, §10 distinct
  strong/weak reports, §11 smooth ladders + medium start, §16
  out-of-scope rejection, §22 weak-first, §24 type⇔data equivalence,
  §26 all photo paths, §27 rubric bands, §29 mastery direction, §30
  global percentage-free sweep, §33 staleness, §60 option grounding.
- 57 exam-feature Dart files pass the brace/paren/string syntax smoke
  check (no Dart SDK in the build environment — same discipline as
  M0–M2).
- The mirror caught 4 real bugs pre-ship (budget overflow, empty plan
  days, fallback cliffs, typed crowding) — all fixed in both the Dart
  source and the mirror.

## 8. What is intentionally NOT in this build

- **M8+** (weak-area recovery days, forgetting curves, official PYQ
  bank, mocks with analysis, home integration, full student
  simulations) — the plan slots exist (`pyq`/`mock`/`weakArea` task
  types, the evaluation log feeds §47), the engines are not built yet.
- AI-generated practice content beyond the grounded bank (§15's
  AI layer) — the bank is fully deterministic and offline-first; the
  generator seam exists in the architecture but V1 ships trusted
  content only.
