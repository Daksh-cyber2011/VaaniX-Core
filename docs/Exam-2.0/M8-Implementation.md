# Exam Mode 2.0 — M8 Implementation: Weak Areas + Revision

Milestone M8 delivers the master plan's dedicated weak-area system
(§21 evidence + weak topic engine, §22 recovery days + targeted
remediation + mastery recheck, §23 forgetting-aware revision
scheduling, §47 error categories) and connects it to the M5 planner.

Everything runs on the same discipline as M3–M7: grounded content
only (§60), honest student-facing language (§30 — never a
percentage), offline-first (§17), evidence never UI-only (§12),
bounded storage (§56), corruption-safe parsing (§41).

---

## 1. Architecture

```
practice loop (M6) ──finalized attempts──▶ ExamAttemptLogRepository
                                              │ (question-level §21 evidence)
                                              ▼
                                     ErrorIntelligence.analyze
                                              │ ErrorPatterns (§21/§47)
        ExamLearnerProfile (§29 stages) ─────┤
        WeakAreaState (§12 persisted)  ─────┤
                                              ▼
                                     WeakAreaEngine.build
                                              │ WeakAreaReport (findings)
                                     RevisionEngine.schedule
                                              │ RevisionItems (§23 ladder)
                                              ▼
                                     WeakAreaDayEngine.decide
                                              │ recovery-day decision (§22)
                                              ▼
   ┌──────────────────────────────────────────┴─────────────────────┐
   ▼                                                                ▼
WeakAreaOverview → Planner (deterministic + Gemini digest)   ExamWeakAreaController
   recovery-day reservation + first-slot review tasks         recovery / revision sessions
   (plan screen deep-links into the hub)                      (RemediationEngine, §22 phases)
```

### Files

| Layer | File | Role |
|---|---|---|
| domain | `domain/weakarea/error_intelligence.dart` | §47 categories, §21 pattern finder |
| domain | `domain/weakarea/weak_topic_engine.dart` | §21 findings, severity, §48 cap |
| domain | `domain/weakarea/revision_schedule.dart` | §23 ladder, schedule, reviewMix |
| domain | `domain/weakarea/weak_area_day.dart` | §22 tiers, gap rules, blueprint |
| domain | `domain/weakarea/remediation_engine.dart` | §22 phases, recheck judging |
| data | `data/weakarea/exam_attempt_log_repository.dart` | question-level evidence (§12/§56) |
| data | `data/weakarea/weak_area_repository.dart` | recovery history + ladder state |
| presentation | `presentation/providers/exam_weakarea_providers.dart` | overview + session controllers |
| presentation | `presentation/screens/exam_weak_area_screen.dart` | the weak-area hub UI |
| planner | `data/planner/deterministic_exam_planner.dart` (amended) | §22/§23 plan connection |
| planner | `data/planner/gemini_exam_planner.dart` (amended) | WEAK AREA prompt digest |
| planner | `domain/planner/exam_plan_validator.dart` (amended) | weakArea = active backbone |
| content | `data/practice/practice_content_bank.dart` (amended) | topicFilter + fixes |

Route: `/exam/weakarea/:trackId` (`RouteNames.examWeakAreaName`).

## 2. Error intelligence (§47/§21)

Classification uses ONLY the honest discriminators the loop persists
(verdict + retries + question kind):

| Evidence | Category |
|---|---|
| correct after retry | carelessMistake (self-corrected slip) |
| revealed | recallGap |
| partiallyCorrect, MCQ | questionInterpretation |
| partiallyCorrect, typed | incompleteAnswer |
| partiallyCorrect, typed, after retry | structureError |
| incorrect after retry | conceptGap |
| incorrect, typed, first-shot | applicationGap |
| incorrect, MCQ, first-shot | recallGap |
| uncertain (photo §26) | NOTHING — input problem, not student error |

Pattern rules (never raw counts — §21 "Do not simply count wrong
answers. Identify PATTERNS"):
- a category must REPEAT on the same topic (≥ 2 occurrences);
- misconception = a conceptGap category with ≥ 3 occurrences OR
  wrong-after-retry twice — still-wrong-after-feedback is the
  signature of a specific recurring wrong belief;
- singletons are dropped: one wrong answer is a mistake, not a
  weakness;
- grammarError and timeIssue are UNFABRICATABLE (the loop does not
  persist grammar/timing rubrics) — they exist in the §47 vocabulary
  but are never emitted (mirror-asserted).

## 3. Weak-topic findings (§21)

Evidence sources (merged, upserted per topic):
1. mastery stages — needsAttention → lowMastery; needsReview (was
   strong, decayed) → forgottenConcept; ≥3 attempts with accuracy
   < 0.4 → repeatedWrong;
2. error patterns — misconception → repeatedMisconception;
   structure/incomplete → poorAnswerQuality; the rest → repeatedWrong;
3. overdue revision items → forgottenConcept.

Severity ladder (qualitative §29/§30 words only):
needsAttention (stage or misconception) > focus (2+ signals) >
watch (single signal). Ranking: severity desc, signal count desc,
strength asc (weakest first), topicId. §48 cap: max 5 findings.
Honesty floors: no evidence at all → "insufficient evidence" state;
PYQ/mock signals (weakPyq/weakMock) are in the vocabulary but NEVER
emitted before M9 data exists.

## 4. Forgetting-aware revision (§23)

The expanding interval ladder is `[1, 2, 4, 7, 15, 30]` days per
topic. Ladder position is EARNED:
- recheck/review pass → `expand` (index + 1, due = now + interval);
- failure → `contract` (index − 2, floor 0 — sharp relearning);
- mastered topics seed at index 2, strong at 1 (their history IS
  retention evidence); learning topics are NOT scheduled (weak-area
  work owns them);
- topics with active error patterns re-enter as relearning items due
  tomorrow — unless persisted history holds an even sooner due date.

Bands (§30 qualitative, never a percentage): fresh / due / overdue
(same-day grace: < 1 day late is still "due"). Internal due dates
exist for scheduling; students only see the band labels.

`reviewMix` (§23 "Do not make revision identical to the original
lesson"): previously-wrong questions first, then round-robin across
topics — mixed practice, never a single-topic block drill.

## 5. Recovery day + remediation (§22)

Frequency tiers ("The system decides frequency based on evidence"):
- struggling (any needsAttention finding) → at most every 3rd study day;
- steady (focus findings or ≥ 2 overdue revisions) → every 5th;
- solid (watch-only / fresh due items) → at most weekly;
- nothing weak, nothing due → NO recovery day ("Do not make every
  day weak-area day").

Hard caps: never back-to-back recovery days within a window; never a
recovery day without evidence; day 0 keeps the §13 normal flow; every
decision ships a §50 rationale sentence.

The recovery session (§22 structure):
```
recap (grounded official sub-topics, §15)
  → mistakeRetry (the topic's previously-wrong questions, ≤3)
  → targetedPractice (fresh questions on the SAME topic)
  → recheck (2 held-aside FRESH questions — never previously wrong,
     never seen earlier in the session)
```
Mastery check: recovered ⇔ every recheck attempt correct or
partially-correct (the §29 contract) AND at least 2 attempts —
anything else is honestly stillNeedsWork. No curve, no percentage.
Recovered → revision interval expands; still weak → contracts, and
the finding stays open for the next recovery.

## 6. Planner connection

Deterministic planner (both hops stay §16/§9-validated):
- the §22 decision RESERVES its day: focus-topic weakArea task leads,
  due revision items fill the remaining budget, one targeted practice
  may follow — NO brand-new learn material that day;
- due §23 items become review tasks in the FIRST slot of normal days
  (review before new material), one per day, spread across the window
  — only when ≥ 2 task slots fit (a 1-slot tiny budget keeps the M5
  shape; §9 budget fit wins);
- out-of-scope revision topics are never scheduled (§16 rule 1);
- the plan rationale states the recovery reservation (§50).

Gemini planner: a bounded WEAK AREA digest (findings + recommended
recovery day + due revision topics) rides in the prompt; when there
is no evidence the section is omitted entirely — never fabricated.

Validator: rule 5 now counts weakArea as an active backbone task (a
§22 recovery day IS intense practice). Review-only days are still
rejected.

## 7. Persistence

- `exam_attempt_log_v1` — per-track question-level evidence: batched
  (one write per finished session, §18), bounded to 300 entries
  (§56), per-track isolation, corrupt-JSON degradation (§41), never
  creates empty entries.
- `exam_weak_area_v1` — per-track state: recovery-day history (§22
  gap evidence), per-topic revision ladder (§23 memory), bounded
  recheck outcome log (100, §56), schema version 1 (§57).
- Derived data (report/schedule/decision) is always COMPUTED from
  the sources — never persisted as a whole (§12).

## 8. Verification

- Dart tests: `test/features/exam/weakarea/` (6 files) — engines,
  repositories (SharedPreferences mock), planner connection (real
  `cbse_10_sanskrit.json`).
- Python invariant mirror: `tools/exam/verify_exam_m8.py` — 1124
  checks, ALL GREEN: engine invariants, repository bounds/corruption,
  planner shapes across 4 courses × 7 budgets (5–120 min) × 4
  study-day patterns × 4 weak-area shapes, prompt digest wiring,
  source-level §30 no-percentage sweep over every Devanagari string,
  sentence parity between the mirror and the Dart sources, and
  Student A (strong) / D (skips → overdue) / H (repeatedly fails one
  topic → misconception → recovery → clean recheck → interval
  expansion → §22 gap rule blocks an immediate second recovery)
  end-to-end journeys — previews of the §M11 simulation milestone.
- Regressions: M1 432/432, M2 124/124, M3–M7 1217/1217 — all green.

## 9. M8 bug fixes in earlier code (found by the mirror)

1. `PracticeContentBank` typed-count `clamp(2, typed.length)` throws
   `ArgumentError` when a pool has exactly ONE typed question —
   single-topic recovery scopes hit this. Fixed with an explicit
   1-typed guard (§41).
2. Topic-filtered pools drew MCQ distractors only from the filtered
   units, thinning single-topic pools to ≤ 2 questions (not enough
   for a §22 recheck). Distractors now come from the whole selected
   scope — still grounded (§60), pools keep up to 3 questions.
3. `ExamAttemptLogRepository.recordSession` created an empty JSON
   entry for a track when a batch carried only empty-id attempts —
   now skipped.
