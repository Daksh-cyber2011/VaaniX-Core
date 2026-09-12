# Exam Mode 2.0 — M9 Implementation: PYQs + Mocks

Milestone M9 delivers the PYQ practice track and the mock ladder
(master plan §25, the "mock progression", §21 pyq/mock performance,
§41 critical-state rules) — and closes the feedback loop: PYQ and mock
results feed the weak-area report (data-gated weakPyq / weakMock
signals) and through it the recovery-day decision and both planner
hops.

---

## 1. §25 provenance — the honesty core

VaaniX's canonical data holds the official syllabus, every item's
official QUESTION PATTERNS (e.g. `अतिलघूत्तरात्मकौ 2×1` with marksEach /
count / totalMarks), official section marks and the official board
structure (80 marks / 3 hours for Class 10) — but NOT the text of past
exam papers. The design is honest about exactly that:

| Provenance | Meaning | Student label |
|---|---|---|
| `official` | A REAL past-paper question (registry-loaded; year/source/marks preserved). The shipped registry is EMPTY — nothing fabricated (§60). Ingestion later is a data drop, not a code change. | आधिकारिक CBSE प्रश्न (PYQ) |
| `examPattern` | Structure (pattern text, marks, kind) VERBATIM from the official syllabus; question text grounded in official strings. | आधिकारिक परीक्षा-पैटर्न पर आधारित |
| `pyqStyle` | Grounded generated practice (marks-structure / chapter-membership MCQs). | PYQ-शैली (अभ्यास) |

Rule (§25, mirror-asserted): NOTHING generated is ever labeled an
actual CBSE PYQ — the words "आधिकारिक CBSE" appear ONLY on the
official label, and `PyqBank` never creates official items.

## 2. PYQ bank (§25 + §60)

For every selected scope unit:
- **Pattern-derived questions** (one per official pattern): the
  pattern text is carried verbatim into the UI; marks = marksEach
  (→ total/count fallback, clamped 0.5..5); the pattern decides the
  kind (§24 — MCQ for बहुविकल्पीय/अतिलघूत्तरात्मक, typed for
  पूर्णवाक्यात्मक/लघूत्तरात्मक/रचनात्मक/निर्माण...; typed only when the item
  has official sub-topic rubric data).
- **Marks-structure MCQs**: "आधिकारिक पाठ्यक्रम में किस विषय पर X अंक
  निर्धारित हैं?" — grounded in the items' official marks.
- **Chapter units (literature)**: grounded membership MCQs (official
  chapter + section titles) so full mocks never silently skip the
  literature section's marks.
- ids are `pyq_`-prefixed → §21 attempt-log evidence from the PYQ
  track stays distinguishable from practice-track evidence.

§25 filtering: section ids, topic ids, marks range, pattern-kind
keywords (AND semantics), limit. Weak topics rank first (§22).

## 3. Mock ladder (§25 structure, §41 determinism)

```
mini     → one board section, capped at 10 marks, ≥15 minutes
section  → one board section at its OFFICIAL marks, ~2.25 min/mark
full     → every board section at official marks, OFFICIAL duration
           (e.g. 80 marks / 3 hours), official total
```

- Board structure comes from the canonical syllabus (section marks,
  board total, duration hours); internal-assessment sections are never
  faked into a mock.
- Question content comes from the PYQ bank (shared §25 discipline);
  the marks budget per section is respected when picking questions
  (pools may be thinner than the official structure — the paper says
  so honestly rather than padding with fabricated questions).
- The session runs on the M6 loop engine (MCQ + typed, feedback,
  retry, reveal) under the paper's honest time limit.
- `MockEngine.analyze` is DETERMINISTIC (§41: mock results are
  critical state — scoring is never AI; Gemini only ever recommends):
  per-section and overall §29-style bands, §21 weak-section
  detection (≥2 attempts in the section), §28-style summary — never a
  percentage (§30).

## 4. Results feed back into planning

- `PyqPerformanceRepository` — per-topic PYQ performance (merged per
  finished session, §56-bounded 60 topics, §41 corruption-safe).
- `MockResultRepository` — bounded results log (40 newest; zero-attempt
  results never stored).
- `WeakAreaEngine` gained two DATA-GATED §21 sources:
  - `weakPyq` — a topic whose real PYQ performance is in the weak
    band with ≥2 attempts;
  - `weakMock` — a section that finished weak in the newest real mock.
  With no PYQ/mock data the report is identical to M8 (the M8
  mirror's no-data contract re-verified after the change: 1124/1124).
- `computeWeakAreaOverview` loads both stores and feeds them in, so
  the findings, the §22 recovery-day decision, the Gemini prompt
  digest and the deterministic planner's reservations all carry
  PYQ/mock evidence automatically.

## 5. UI + routes

- `/exam/pyq/:trackId` — section filter chips, the session loop, a
  per-topic PYQ progress card (bands only, "कम-से-कम 2 प्रश्न हल होने पर
  ही राय बनती है").
- `/exam/mock/:trackId` — the ladder cards (mini/section/full with
  honest marks/time), the live timer, per-section results, bounded
  history.
- The plan screen's `pyq` / `mock` task slots (honest slots since M5)
  are now actionable deep-links.

## 6. Files

| Layer | File | Role |
|---|---|---|
| domain | `domain/pyq_mock/pyq_models.dart` | §25 provenance, filter, performance |
| domain | `domain/pyq_mock/pyq_bank.dart` | grounded bank builder |
| domain | `domain/pyq_mock/mock_models.dart` | ladder models, results, bands |
| domain | `domain/pyq_mock/mock_engine.dart` | paper assembly + deterministic analysis |
| data | `data/pyq_mock/pyq_performance_repository.dart` | PYQ perf + mock results stores |
| presentation | `presentation/providers/pyq_mock_providers.dart` | both controllers |
| presentation | `presentation/screens/exam_pyq_screen.dart` | PYQ UI |
| presentation | `presentation/screens/exam_mock_screen.dart` | mock UI |
| amended | `domain/weakarea/weak_topic_engine.dart` | data-gated weakPyq/weakMock |
| amended | `presentation/providers/exam_weakarea_providers.dart` | overview feeds |
| amended | router / route_names / plan screen | routes + deep-links |

## 7. Verification

- Dart tests: `test/features/exam/pyq_mock/` (models/bank/engine +
  repositories, real assets) + 6 new data-gated signal tests in
  `weak_topic_engine_test.dart`.
- `tools/exam/verify_exam_m9.py` — 122 checks ALL GREEN: §25 label
  sweeps + source wiring, pattern-verbatim + marks checks across all
  7 courses, mock structure verified against the OFFICIAL 80/3h board
  data, deterministic analysis, §30 sweeps, repository bounds /
  isolation / corruption, M8 no-data parity, and Student B's journey
  (weak PYQ topic + weak mock section → findings → frequent recovery
  tier → the plan reserves the day for that topic → deterministic
  persistence).
- Full regression sweep: M1 432/432 · M2 124/124 · M3–M7 1217/1217 ·
  M8 1124/1124 · M9 122/122. Syntax: 25/25 (M8 set) + 18/18 (M9 set).

## 8. What M9 deliberately does NOT do (honest)

- No fabricated past-paper text: the official registry ships EMPTY;
  only a data drop of real PYQs can activate `PyqProvenance.official`.
- Mock papers may be thinner than the official marks structure when
  the grounded pool is thin — shown honestly, never padded.
- XP/streak/achievements for mock completion are M10 (gamification
  glue); the plan's pyq/mock slots were already honest since M5.
