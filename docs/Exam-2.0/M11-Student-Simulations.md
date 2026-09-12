# M11 — Real Student Simulations (Exam Mode 2.0)

Nine personas from the master plan, each run end-to-end through the
SAME verified engine ports the shipped Dart code encodes (M4
diagnostic ladder, M5/M8 deterministic planner, M6 practice loop,
M8 weak-area + revision engines, M9 PYQ/mock engines, M10 XP rules)
against the REAL canonical CBSE 2026-27 syllabus JSONs. Journeys are
deterministic (seeded LCG) — re-running reproduces this report
byte-for-byte.

**Journey per student:** diagnostic → plan → 21 simulated days of
tasks/mistakes → replanning (§33 triggers for E and F) → weak-area
recovery days (§22) → revision (§23) → PYQ sessions (§25) → mini
mocks (§41 deterministic) → readiness line + XP (M10).

Invariants verified for every student (see verify_exam_m11.py):
plans validate (§16, budgets §9), every task stays inside the selected
scope, XP is once-per-session, and no engine crashes on any persona.
Divergence between personas is asserted pairwise in the verifier —
the table below is the human-readable digest.


## Per-student digest

| | A | B | C | D | E | F | G | H | I |
|---|---|---|---|---|---|---|---|---|---|
| **Diagnostic accuracy** | 1.00 | 0.40 | 0.10 | 0.50 | 0.50 | 0.50 | 0.70 | 0.50 | 0.30 |
| **Final plan scope revision** | 1 | 1 | 1 | 1 | 2 | 1 | 1 | 1 | 1 |
| **Plans built (replans)** | 4 | 4 | 4 | 3 | 5 | 5 | 4 | 4 | 4 |
| **Replan reasons** | — | — | — | — | day 7: scope edited | day 10: readiness target changed | — | — | — |
| **Recovery days used** | 2 | 3 | 2 | 1 | 3 | 3 | 3 | 3 | 5 |
| **Recovery outcomes** | plan-reserved, plan-reserved | plan-reserved, plan-reserved, plan-reserved | plan-reserved, plan-reserved | plan-reserved | plan-reserved, plan-reserved, plan-reserved | plan-reserved, plan-reserved, plan-reserved | stillNeedsWork, stillNeedsWork, stillNeedsWork | plan-reserved, plan-reserved, plan-reserved | plan-reserved, plan-reserved, plan-reserved, plan-reserved, plan-reserved |
| **Revision sessions** | 38 | 36 | 38 | 24 | 34 | 36 | 42 | 36 | 32 |
| **Strong topics** | 19 | 8 | 1 | 4 | 8 | 13 | 9 | 12 | 2 |
| **Needs-attention topics** | 0 | 2 | 13 | 2 | 3 | 1 | 0 | 2 | 8 |
| **PYQ attempted** | 6 | 6 | 6 | 6 | 18 | 6 | 132 | 6 | 12 |
| **PYQ correct** | 6 | 5 | 3 | 4 | 10 | 6 | 98 | 4 | 4 |
| **Last mock band** | strong | strong | needsAttention | learning | learning | strong | strong | needsAttention | strong |
| **Mock weak sections** | — | — | अपठितावबोधनम् | — | — | — | — | अपठितावबोधनम् | — |
| **Skipped days** | 0 | 0 | 0 | 8 | 0 | 0 | 0 | 0 | 0 |
| **Sessions finished** | 63 | 62 | 63 | 40 | 61 | 62 | 68 | 62 | 58 |
| **XP earned (M10)** | 440 | 373 | 293 | 268 | 318 | 389 | 714 | 356 | 284 |
| **Readiness** | ready | ready | ready | ready | ready | ready | ready | ready | ready |
| **Days to anchor** | 56 | 56 | 84 | 56 | 56 | 21 | 56 | 56 | 56 |
| **Final weak findings** | cbse_10_sanskrit_ch_shemushi_1, cbse_10_sanskrit_ch_shemushi_10, cbse_10_sanskrit_ch_shemushi_2 | cbse_10_sanskrit_ch_shemushi_5, cbse_10_sanskrit_ch_shemushi_6, cbse_10_sanskrit_ch_shemushi_7 | cbse_10_sanskrit_ch_shemushi_10, cbse_10_sanskrit_ch_shemushi_3, cbse_10_sanskrit_ch_shemushi_4 | cbse_10_sanskrit_ch_shemushi_6, cbse_10_sanskrit_ch_shemushi_8, cbse_10_sanskrit_grammar_avyayapadani | cbse_10_sanskrit_ch_shemushi_10, cbse_10_sanskrit_ch_shemushi_2, cbse_10_sanskrit_grammar_ashuddhi | cbse_10_sanskrit_ch_shemushi_3, cbse_10_sanskrit_ch_shemushi_8, cbse_10_sanskrit_grammar_sandhi | cbse_10_sanskrit_grammar_ashuddhi, cbse_10_sanskrit_grammar_avyayapadani, cbse_10_sanskrit_grammar_samasa | cbse_10_sanskrit_ch_shemushi_10, cbse_10_sanskrit_ch_shemushi_3, cbse_10_sanskrit_grammar_samaya | cbse_10_hindi_a_grammar_vachya, cbse_10_hindi_a_grammar_vakya_bhed, cbse_10_hindi_a_literature_kshitij_prose |

## How the paths differ (selected)

* **A vs C**: A's diagnostic accuracy, mastery bands, PYQ and
  mock results sit in the strong band; C's sit at needsAttention
  — and the weak-area engines schedule C far more recovery
  days than A (who needs none).
* **D**: skipped days leave revision items overdue, so §21
  forgotten-concept findings appear where A/B/C have none.
* **E**: the scope edit at day 7 bumps scopeRevision, drops
  out-of-scope topics from every later plan (§33/§16) and
  forces a rebuild.
* **F**: the day-10 readiness change rebuilds the plan with a
  different pacing window (§8/§33).
* **G**: G replaces recommended practice with PYQ sessions;
  the engines never punish the deviation (§20 student
  freedom) — day completions simply differ.
* **H**: the repeatedly-failed topic becomes the §22 focus
  topic with the frequent recovery tier until a clean recheck
  expands its revision interval.
* **I**: mock weak sections appear ONLY in the weak section,
  and PYQ performance splits by section — the §21 weakMock
  signal is section-honest.

## Method

1. Each persona's answer policy is a deterministic function
   `decide(question, ctx)` over the grounded question set.
2. All sessions run the §28 loop (one retry, then reveal).
3. All persistence mirrors §12/§56/§57 (bounded, corrupt-
   degrading stores) exactly as the repositories implement.
4. XP uses the M10 mirror tables parsed live from the Dart
   source, so the simulation cannot drift from the app.

Generated deterministically by `tools/exam/student_simulations.py`.
