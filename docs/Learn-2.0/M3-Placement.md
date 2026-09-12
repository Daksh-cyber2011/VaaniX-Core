# Learn Mode 2.0 — M3: Adaptive Placement & Diagnostic

Milestone: M3 of the Learn Mode 2.0 transformation (see
`docs/Audits/Learn-2.0-M0-Audit.md` §12 for the plan and gap map).
Status: **COMPLETE** (static validation suite green; `flutter test`
remains a user-machine step, as documented in M0–M2).

---

## 1. What M3 delivers

The learner no longer has to guess their level. VAN invites every new
learner to a short, friendly, genuinely adaptive discovery game and the
structured result becomes a first-class input of the Learn Mode 2.0
spine:

```
Learn screen ──► "Discover your level" card
                        │
                        ▼
        /learn/diagnostic  (VAN-led, game-like)
                        │
        DiagnosticEngine (§12 strategy, trusted pools)
                        │
                        ▼
        DiagnosticResult (structured, never raw)
          │            │              │
          ▼            ▼              ▼
  profile.currentLevel  state extras   PlannerContext.diagnostic
  (LearnerProfile)      (review queue  (§13 planner input,
                         + performance   exposed in the M4 digest)
                         events)
```

Master Brief coverage: §11 (adaptive placement test), §12 (genuinely
adaptive difficulty strategy), §43 (game, not exam), §44 (no raw
scores / no jargon), §13 pre-wiring (diagnostic results as planner
input), §29 (internal level names, no CEFR claims).

## 2. The adaptive strategy (Brief §12, implemented)

`DiagnosticEngine` (pure Dart, `spine/diagnostic_engine.dart`) runs a
probe-by-probe state machine:

1. **Seed** — the starting difficulty track (0–4) comes from the M2
   self-report hint (`SelfReport.suggestedLevel`). It is never shown to
   the learner as a level.
2. **Baseline probe** — the first probe is always from the
   `script` dimension (the gateway skill), at the seeded band.
3. **Two consecutive correct → harder** — the track moves up one step;
   the next probes come from the higher difficulty band.
4. **A miss → prerequisite** — the track moves down one step AND the
   next probe is a *true prerequisite*: the same dimension, the nearest
   unasked item EARLIER in curriculum order.
5. **Dimension rotation** — round-robin over dimensions that still need
   evidence, in a fixed priority order (script → vocabulary → grammar →
   sentence-formation → reading → practical → …). Dimensions without
   trusted pools are skipped, never faked.
6. **Stop rules** — the run ends when:
   - every measurable dimension has its evidence target (2 probes), or
   - the probe budget is reached (hard cap 16), or
   - the trusted pools run dry (short content = shorter game).
   With the floor at 8 probes this realizes the brief's 3–7 minute
   budget (≈20–30 s per probe over 8–16 probes).
7. **Result** — per-dimension score = first-try correct/asked with an
   evidence-based confidence; overall level blends the difficulty track
   with the confidence-weighted measured level. Only dimensions with
   real answers appear — nothing is fabricated from seeds.

Determinism: for a fixed bank, seed and answer script the whole run is
reproducible (unit-tested). Each run reshuffles its pools from the
trusted content, so retakes vary their probe list.

## 3. Honesty guarantees

- **Trusted content only** — probes are resolved from the exercise banks
  through the concept graph. The diagnostic can never ask anything the
  app does not authoritatively know.
- **Only measurable dimensions** — with the A–G banks that is script,
  practical, vocabulary, grammar, reading and sentence-formation
  (classification: chapter theme × exercise type, with forward-
  compatible rules for ordering/fillBlank when banks add them).
  LISTENING is never scored (no audio exists); COMPREHENSION is left
  unmeasured rather than faked (brief §11).
- **First-try scoring** — one answer per probe, no retries inside the
  run, so scores stay truthful estimates.
- **No raw scores in the UI** — the result view renders
  `friendlySummary()` lines and the internal level name only. The new
  `weakDimension` getter (score < 0.6) prevents a perfect run from
  getting a fake "biggest opportunity" line; the M1 `weakestDimension`
  contract is unchanged.
- **Stub languages** — kn/ml/or (or any language without lessons) get
  an honest "Not ready yet" unavailable state instead of a broken flow.
- **No sensitive data** — the only new storage is the placement result
  and learning extras under the existing `learn_profile_*` namespace
  (Master Brief §35, local-only).

## 4. Storage (extends the M2 repository, additive)

| Key | Content | Written by |
|---|---|---|
| `learn_profile_<iso>` | profile JSON (unchanged shape; `currentLevel` now filled by M3) | M2 + M3 finish pipeline |
| `learn_profile_<iso>_state` | review queue + recent performance extras | M3 finish pipeline (M6 later) |
| `learn_profile_<iso>_diagnostic` | last `DiagnosticResult` JSON (retake overwrites) | M3 finish pipeline |

All three slots share the corruption-safety contract (missing /
malformed / wrong-language → treated as unset, never crash) and the
prefix-scoped `clearAll()`.

## 5. Wiring (one-way dependency graph)

```
spine_providers ──► diagnostic_providers ──► (domain: engine, model)
     │                        │
     │                        ├── exercise banks + active curriculum
     │                        └── profile repo / profile notifier
     └── watches lastDiagnosticProvider + learnStateExtrasProvider
```

`diagnostic_providers.dart` never imports `spine_providers.dart`; the
probe bank derives its own concept graph from the active curriculum
with the same one-line rule the spine uses. The spine's
`activeLearningStateProvider` merges the extras (derivation stays
authoritative for masteries), and `activePlannerContextProvider`
carries the structured result — completing the Diagnostic → Planner
edge for M4.

## 6. UI surfaces

- **Learn screen** — placement card in two states: "Discover your
  level" invitation (shown once the language has real lessons) and
  "Your path starts at {level}" with a quiet retake entry. Never
  blocks the lesson tree.
- **Diagnostic screen** (`/learn/diagnostic`, auth-gated via the
  `/learn/` prefix like all Learn sub-routes) — VAN intro, friendly
  round meter ("Round 3 of about 12"), encourage-first feedback beats
  with the real explanation, VAN achievement result with the friendly
  summary, "See my path" + "Play again".
- **Profile screen** — level-check card: friendly internal level name
  or the invitation (no CEFR, no scores).

## 7. Tests (5 new files; run with `flutter test` on a user machine)

- `spine/diagnostic_item_bank_test.dart` — real hi/bn content: exactly
  the six measurable dimensions, trust anchors resolve, uniqueness,
  exclusion sets, reshuffle honesty, stub emptiness.
- `spine/diagnostic_engine_test.dart` — §12 strategy (streak bumps,
  prerequisite follow-ups), full-run outcomes (perfect → level 4 with
  clean scores; struggling → level 0; mixed → middle band), budget
  bounds, answer records, no raw numbers in summaries, one-probe-only
  result honesty, determinism, answer-checker parity with the practice
  engine.
- `learn_profile_repository_diagnostic_test.dart` — round-trip,
  isolation, corruption, wrong-language guard, retake overwrite,
  `clearAll` coverage, key naming.
- `diagnostic_providers_test.dart` — end-to-end perfect / struggling /
  retake runs over the real curriculum with persistence asserts
  (result + extras + `currentLevel` + spine pickup +
  `PlannerContext.diagnostic`), stub unavailability, phase guards.
- `diagnostic_screen_test.dart` — widget flow over real content: intro
  (exam-free copy), full happy path through REAL taps to the result
  view (no raw scores rendered), feedback beat, unavailable state.

## 8. Preservation (verified by `scripts/m3_validate.py`)

Byte-level diff vs the M2 ZIP: **8 added files, 0 removed, 7
allow-listed modified files** (`spine/diagnostic.dart`,
`learn_profile_repository.dart`, `spine_providers.dart`,
`learn_screen.dart`, `learn_profile_screen.dart`, `app_router.dart`,
`route_names.dart`) + CHANGELOG. All A–G curricula, Exam Mode, VAN, AI
chat stack, XP/streaks/achievements, global UserProfile, onboarding,
auth and signing are untouched.

## 9. What M4 plugs into

- `learningPlannerProvider` remains the single planning boundary — the
  Gemini planner slots in as the delegate with the fallback chain
  intact.
- `PlannerContext.diagnostic` is now populated; the structured digest
  exposes `overallLevel` + per-dimension scores to prompt assembly.
- `LearnerProfile.currentLevel` is live; pre-M3 profiles (null level)
  keep working — the planner treats them as starter by contract.
- The review queue seeded by the diagnostic is the first consumer
  surface for M6's session kinds (review/repair).
