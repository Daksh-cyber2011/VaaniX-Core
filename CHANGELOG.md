## [VaaniX Final Polish — Production Experience] - 2026-09-12

The whole-application polish pass ("Million-User Quality") on top of the
M12 freeze: production-critical defect fixes, dark-theme contrast repair,
navigation dead-end removal, Urdu RTL parity for the two remaining
exercise surfaces, an accessibility parity sweep, shared-state-widget
adoption, motion/copy normalization, and one honest AI-failure
regression test. Exam Mode untouched except two 2-line shared-system
fixes (spinner label + VAN error expression). Full audit:
docs/Polish/Final-Polish-Audit.md.

### Fixed — production-critical
- Raw exception text never reaches learners: onboarding completion
  snackbar, chat error banner (adapter default branch + defensive
  catch), unmapped auth failures, and the planner/material Failure
  messages (documented human-readable) now carry calm, actionable copy.
- Dark-theme contrast: `AppColors.subtextLight` used unconditionally in
  smart practice (5 sites) and the light-theme primary indigo used for
  text/icons on dark surfaces across progress, achievements, settings
  and chat (~20 sites) now resolve through the theme (deep AA-safe
  semantic tokens added for small coloured text on light tints).
- Navigation dead-ends: Chat / Settings / Achievements open with
  `push` so the AppBar back button exists; system back no longer
  exits the app from those screens. Auth "Skip for now" is hidden when
  the Supabase guard would silently bounce the user straight back.
- Progress screen: a failed or loading chapter list no longer reads as
  silent zeros — branded loading and an error view with real retry.
- Practice matching review label no longer jams the two sides of a
  pair into one token.

### Added — accessibility
- RTL parity for the legacy exercise path and the diagnostic game
  (Urdu prompts, options, ordering/matching chips, translation fields,
  hints and feedback now lay out right-to-left like the spine screens).
- Semantics parity: diagnostic choice/pair tiles and smart-practice
  kind chips + generated quiz options carry one labelled semantics node
  each; four tappable cards announce as buttons; the exercise header
  progress bar and all previously silent spinners have semantics
  labels; sub-48dp touch targets raised to the Material floor
  (kind chips, minute chips, match/pair tiles); onboarding page
  position ("Page N of 6") is announced; the companion-name field has
  a visible label; app-bar mini-Vans are named via Tooltip.
- Chat error banner offers a real Retry (drops the unanswered bubble
  and re-sends; no duplicate transcript).

### Changed — consistency
- Shared-state adoption: `VaaniXLoadingIndicator` (diagnostic),
  `ErrorStateWidget` (progress), `VanSpeechStrip` (Home curriculum
  error, first adoption), PrimaryButton retry (Learn shelf error, now
  a live region with honest bundled-asset copy).
- VAN context correctness: the Learn shelf error and the exam load
  failure use the confused/reassuring error expression instead of the
  tired "sad" / sustained "thinking" poses.
- Motion tokens (`AppMotion`) adopted where values matched or
  misfit (120/180/300/400ms collapse to fast/base/slow); route-string
  constants replace raw paths; pill radii use `AppDimens.radiusPill`;
  retry CTAs unified on "Try again"; "Practice" spelling unified;
  splash subtitle reflects 10 Learn languages; splash navigates at
  1.4 s (animation floor) instead of a fixed 2 s; stray
  placeholder/double-space/trailing-space copy cleaned; language
  picker footer count is data-driven.

### Tested
- New regression test: unmapped AI client exceptions produce a calm
  AiServiceFailure with no raw host/exception text
  (test/features/learn/ai_reliability_test.dart). flutter analyze/test
  remain UNVERIFIED in this environment (no Flutter SDK); every change
  is brace-balanced and import-audited, and no test was disabled.

## [Learn Mode 2.0 — M12 Final Polish + FREEZE] - 2026-09-11

Twelfth and final milestone: the Learn Mode 2.0 FREEZE. A closing
quality-bar sweep (loading/error/empty states, copy, VAN feedback,
performance bounds, Unicode/RTL, offline behaviour, AI fallback — all
audited, nothing redesigned), two real accessibility gaps fixed, and
the freeze declaration with the final report (docs/Learn-2.0/
M12-Final-Freeze.md).

### Fixed — accessibility (Master Brief §94)
- `session_screen.dart` choice options: the post-answer "correct"
  state is no longer colour-only — one semantics node per option
  carries `Option N: <text>` + `, correct answer`, with
  selected/enabled/button flags (mirrors the practice engine's
  pinned pattern in exercise_screen).
- `session_screen.dart` matching tiles: the "waiting for its match"
  state now carries `selected: true` and a spoken
  "selected — now choose its match below" label instead of a
  colour-only highlight.

### Frozen
- Learn Mode 2.0 frozen at M12 (2026-09-11): complete
  replacement-ready project — source, assets, curricula A-J, tests,
  configuration, documentation; no private secrets. All eleven §95
  quality-bar questions answered in the freeze doc.

## [Learn Mode 2.0 — M11 End-to-End Learner Simulation] - 2026-09-11

Eleventh milestone: the proof. Complete learner journeys — onboarding,
diagnostic, plan, lesson, exercise, mistakes, mastery, review,
replanning — driven through the REAL spine on REAL trusted data for
five personas (beginner / vocab-strong-grammar-weak / strong beginner /
lopsided / returning), and the §92 demonstration: two learners on the
SAME language receive DIFFERENT plans, every difference traceable to
their state.

### Added
- `test/features/learn/simulation/e2e_learner_simulation_test.dart`:
  the five §91 journeys + the full §18 ladder transcript on real bank
  data + the §92 divergence proof + a determinism canary, all through
  the real engines (diagnostic engine, deterministic planner behind
  the validating facade, adaptive session engine, mastery scheduling,
  trusted registry, shipped Hindi curriculum + bank).
- `docs/Learn-2.0/M11-E2E-Simulation.md` + the runnable Python mirror
  of the spine rules used to validate the scenarios before the freeze
  (34/34 checks passed; it caught two scenario-design errors — stages
  only rise, so challenge must precede the mastery check, and a
  returning learner's prior must respect the prerequisite ladder).

## [Learn Mode 2.0 — M10 AI Reliability] - 2026-09-11

Tenth milestone: adversarial hardening. The brief's full §90 matrix —
empty responses, wrong language, hallucinated concepts, invalid
exercises, malformed JSON, missing fields, very long responses,
unexpected Unicode, timeouts, rate limits, offline, stale caches — now
runs against the AI planner and content generator in tests, and every
case recovers safely (typed Left, never a throw, never a broken UI).
Two audit gaps closed: raw replies are bounded before parsing, and
invisible/bidi-manipulation characters are rejected while legitimate
Indic orthography (ZWNJ/ZWJ) stays allowed.

### Hardened
- `planner_prompt.dart`: 256 KB raw-response cap before scanning.
- `generated_content.dart`: `unsafeCharacters` rejection across all
  text fields of generated material.

### Verified
- `ai_reliability_test.dart`: all 12 §90 cases + recovery proofs
  (deterministic fallback plans after every failure; honest declines
  fall back to trusted content).

## [Learn Mode 2.0 — M9 All Ten Languages] - 2026-09-11

Ninth milestone: the knowledge fills in. Kannada (Part H), Malayalam
(Part I) and Odia (Part J) ship complete native-script curricula —
5 chapters × 4 lessons each — with authored practice exercises, closing
the ten-language catalogue. All ten languages now pass the §74 support
matrix through the SHARED engine; no per-language engines exist.

### Added — Part H/I/J curricula (kn / ml / or)
- Full native-script lesson content (script fundamentals → greetings →
  daily life → grammar → reading), schema-identical to Parts A–G,
  with mini-practice closers per lesson.
- 3 grounded exercises per lesson in three new banks (60 per
  language, all five engine types, why-first explanations).

### Changed — data-driven availability
- `exercise_providers.dart`: kn/ml/or banks join the fallback chain
  (additive, contract unchanged).
- `learn_screen.dart`: the curriculum-availability banner is derived
  from the LOADED curriculum — the hardcoded language list is gone;
  future languages need zero UI changes.

### Verified
- §74 support matrix test for ALL 10 languages: profile, script,
  direction, knowledge data, content mapping, exercise support,
  diagnostic/planner/mastery derivability, milestone ordinals.
- §76 Urdu stays RTL; §77 Unicode mojibake guard (kn/ml/or are
  foreign-block-free, enforced at generation and in tests);
  §84 Exam Mode isolation (no `ls_` leaks, banks disjoint).

## [Learn Mode 2.0 — M8 Restoration + Gamification Integration] - 2026-09-11

Eighth milestone: a CORRECTION release. The M7 package had been built
from a stale pre-2.0 baseline, so although its new gamification layer was
complete, it silently shipped WITHOUT the entire Learn 2.0 spine
(M1–M6: LearnerProfile, Diagnostic/Placement, LearningState, Planner,
Session, Mastery, the adaptive exercise engine, and their 33 test
files + milestone docs). This release restores the full spine and
re-integrates the M7 gamification layer on top of it — verified by a
file-inventory audit and a Dart import-resolution audit across the whole
tree. Additive only; nothing existing replaced.

### Fixed — missing spine restored
- Restored all 74 missing files: the complete
  `lib/features/learn/domain/spine/` domain (learner profile, diagnostic,
  learning state, planner, session, mastery, concept graph, trusted
  content registry, generated content), the Learn 2.0 data repositories
  (`learn_profile_repository`, `learn_plan_repository`,
  `gemini_planner`, `generated_content_repository`,
  `personalized_content_generator`), their providers (spine, diagnostic,
  plan, profile, content, session), the placement/profile/session/smart
  practice screens, 33 spine test files, the M0 audit + M1–M6 milestone
  docs, and the M6 active-language adaptive test.
- Re-verified the M7 overlay was lossless: every shared file M7 touched
  (analytics event, exam/home/progress/settings screens, exercise and
  lesson screens, VAN event/reaction, settings reset test) was NOT
  touched by the M1–M6 line, so the overlay introduced no regressions.

### Integrated — M7 gamification on the full spine
- 9 competency learning milestones evaluated from REAL persisted
  evidence (milestone engine + repository + checker + bonus-XP ledger).
- Daily goal (2 XP per promised minute) and daily review challenge
  (+15 XP, once per day) with 7-day-bounded daily activity storage.
- Home Nest strip (daily goal + review challenge), Progress
  LEARNING MILESTONES section with honest progress meters, VAN
  milestone celebration, analytics events, settings-reset purge of all
  M7 keys.

### Verified
- Inventory: 1336 files = M6's 1326 + M7's 10 new gamification files;
  every M1–M6 spine file and every M7 gamification file present.
- Import audit: every Dart import in `lib/` and `test/` resolves to a
  file inside the tree (no dangling `package:vaanix_app/...` imports).
- Delivery: full project zip -> Python chunks + JOIN_ME.py (per-part
  size + SHA256, whole-file size + SHA256, missing/corrupt part
  detection). No BAT anywhere in the chain.

## [Milestone 7 — Gamification, Milestones & Progression] - 2026-09-11

The gamification upgrade: competency learning milestones, the daily-goal
loop and the daily review challenge — all evaluated against REAL persisted
evidence (completed lessons, practice mastery, exam attempts, streaks),
never tap-counters. No Duolingo copy; the vocabulary is VaaniX's own.

### Learning milestones (9, competency-based)
1. 🌱 First Words — first lesson completed AND first exercise mastered
2. 🔤 Script Explorer — foundations chapter: every lesson read, every
   practice exercise mastered
3. 👋 First Conversation — greetings & introductions chapter at 100%
4. 💬 Everyday Communicator — daily-life chapter at 100%
5. 🧠 Grammar Builder — grammar chapter at 100%
6. 📖 First Reader — reading & writing chapter at 100%
7. 🏆 Beginner Complete — every lesson, every exercise, every exam
8. 🔥 Consistent Learner — 7-day real learning streak
9. 💎 Mastery Milestone — full journey at 80%+ exam standard

Engine is pure and deterministic (`learning_milestones.dart`): criteria
are configurable subclasses over a `MilestoneEvidence` snapshot built
exclusively from the persisted providers the adaptive engine already
trusts. Chapter criteria map to chapter ORDINALS so one definition set
works for every Learn Mode language (missing ordinals stay honestly
locked). Unlocks persist via `MilestoneRepository` (`ms_<id>` keys), pay
bonus XP through the idempotent bonus-XP ledger, fire VAN's
`milestoneUnlocked` celebration (new event type → achievement state) and
a typed analytics event. Checked at the same lifecycle points as
achievements: lesson completion, practice completion, exam completion
and Home streak updates.

### Daily goal
The onboarding goal (minutes) maps to XP at 2 XP/minute via
`daily_goal.dart`; a bounded `DailyActivityRepository` records XP earned
per day (`daily_xp_<date>`, 7-day retention) only through real learning
events. Home shows a compact Daily Goal + Review Challenge strip under
the Nest; crossing the goal fires `dailyGoalReached` once per day.

### Daily review challenge
The adaptive weak-area engine's weakest lesson becomes a once-per-day
challenge; finishing its practice to full mastery pays +15 XP through
the date-keyed bonus ledger (`review_<date>` — can never double-pay) and
fires `reviewChallengeCompleted`. Exercise screen claims it after the
mastery save.

### Progress screen
New LEARNING MILESTONES section: every milestone card shows its honest
progress fraction and the exact current-evidence line ("3 of 5 lessons ·
8 of 12 exercises") — a locked milestone always says what is missing.

### Reset & hygiene
Settings → Reset Progress now also clears unlocked milestones and daily
activity counters (milestones re-earnable, fresh daily loops). Storage
stays bounded: day-keyed counters prune after 7 days.

### Preserved: Learn Mode Parts A–G (10-language catalogue), Exam Mode,
VAN, AI, XP, streaks, achievements, signing, all existing tests.


## [Learn Mode 2.0 — M6 Adaptive Exercise Engine] - 2026-09-11

Sixth milestone: the exercise engine is now ADAPTIVE. It understands all
SIX activity kinds (new learning, practice, review, weak-area repair,
mastery check, challenge — Master Brief §18), reduces repetition after
repeated success, and on repeated failure descends the §18 ladder
(prerequisite → explanation → easier → guided → normal) without ever
repeating the same question. Sessions now also drive the mastery model:
the §19 upper stages (recalled / applied / mastered / maintained) are
EARNED through kind-specific evidence gates, and the §20 practical
review policy schedules recently-weak, aging-strong and maintenance
reviews. AI-generated exercises from the M5 validated cache enter
sessions as easier/guided rungs — labelled, and never writing progress.
Additive only; nothing existing replaced.

### Added — adaptive session engine (`spine/session_engine.dart`)
- `AdaptiveSessionEngine` + `SessionStep` + `SessionExercisePool`:
  per-kind session shaping (1/2/3 exercises per concept by kind), live
  adaptation from answer records, the §18 ladder built ONLY from
  trusted material (plus validated generated variants), a no-repeat
  guarantee via asked+reserved id sets, free support beats outside the
  exercise budget, and `buildEvaluation()` producing the M1
  `EvaluationResult`.
- `AdaptiveSessionPolicy`: the named tunables (trim after 2 first-try
  corrects, ladder after 2 wrongs, hard budget ceiling).

### Added — mastery scheduling (`spine/mastery_scheduling.dart`)
- Evidence-gated stage uplifts (§19): review→`recalled` (mastered→
  `maintained`), challenge→`applied`, masteryCheck (≥80% first-try,
  ≥2 probes)→`mastered`; wrong answers and the lower kinds never
  uplift; nothing is recalled that was never learned.
- `ReviewPolicy` (§20): recentlyWeak due +1d (priority 0.85),
  agingStrong due +3d (0.5), maintenance due +7d (0.3); queue merge
  with per-concept replacement and a 12-entry cap.
- `applyMasteryEvidence`: the never-lower overlay of persisted session
  evidence onto the derived state (derivation stays authoritative for
  stages reachable from progress data; evidence adds upper stages,
  recency, due dates).

### Added — live session wiring + UI
- `presentation/providers/session_providers.dart`:
  `AdaptiveSessionController` — resolves trusted pools + cached M5
  generated variants (ZERO AI calls; personalization stays
  learner-triggered), drives the engine with diagnostic-style pacing,
  and finishes persist-first (evidence masteries + review queue +
  performance events into the existing `learn_profile_<iso>_state`
  channel) before publishing. Trusted-exercise mastery flows through
  the EXISTING idempotent progress path; generated `gen-` ids are
  never recorded.
- `presentation/screens/session_screen.dart` (`/learn/session`): the
  guided session runner — all five engine types, honest ladder labels
  (Warm-up / Foundations / Easier step / Guided step / Refresher),
  "Made for you · AI" badges on generated rungs, encourage-first
  feedback (§44), friendly finish view, honest footer (sessions tune
  the path; lesson XP stays in lessons).
- `activeLearningStateProvider` overlays the persisted evidence
  (additive); Smart Practice's focus card gained a "Start guided
  session" entry.
- Fixed: `VanState.confused` → `VanState.caring` in Smart Practice's
  unavailable view (undefined symbol that slipped past M5 static
  checks).

### Tests
- 6 new files: adaptive engine (six-kind shaping, trimming, ladder
  order + honesty skips, generated-rung adoption, no-repeat, budget,
  evaluation, real-bank parity), mastery scheduling (uplift gates,
  review windows, merge/cap, overlay never-lower, JSON round-trip),
  provider persistence + spine pickup + honest unavailable states +
  mastery-check uplift, and the session screen widget flow.

## [Learn Mode 2.0 — M5 Dynamic Learning Content] - 2026-09-11

Fifth milestone: content selection and generation is dynamic. The A–G
static curricula are now classified as TRUSTED SEEDED CONTENT available
to the AI (Master Brief §15/§32), a Smart Practice screen resolves each
plan step to its trusted lesson + exercises FIRST (§34 priority
ladder), and the learner can request AI-personalized explanation /
example / practice material that is generated ONLY from the trusted
knowledge excerpt and must pass the §45/§46/§47/§48 validation gate.
Additive only; nothing existing replaced.

### Added — trusted content registry (`spine/content_registry.dart`)
- `TrustedContent` + `TrustedContentRegistry`: every A–G chapter/lesson/
  exercise becomes an addressable trusted entry (lesson entries carry
  their exercise-bank count; exercise entries carry their type) — no
  content moved or rewritten, only classified (§32 "use existing content
  as trusted seeds").
- `TrustedKnowledgeExcerpt`: per-concept trusted vocabulary (answer
  words first), trusted example sentences and the lesson reference text,
  all extracted VERBATIM from the shipped curriculum + banks — the
  grounding layer §16 demands, with honest emptiness for stub material.
- `difficultyKnobForBand`: inverse of the M4 planner knob mapping.

### Added — generated material + validation gate
(`spine/generated_content.dart`)
- `GeneratedContentKind` (explanation / example / practice),
  `GeneratedExampleLine`, and `GeneratedContent` — practice material is
  a REAL trusted-shape `Exercise` with FORCED concept/lesson anchors and
  fresh ids (the model can never re-anchor or collide with trusted ids).
- `GeneratedContentValidator`: enforces the §45 minimum list (language,
  difficulty, structure, required fields, supported exercise type,
  expected answer, explanation) plus §47/§48 script guards (target-
  language text in the wrong script is discarded) and §45's
  compare-against-trusted-vocabulary grounding check (an empty excerpt
  grounds NOTHING). Every violation is a typed rejection; invalid
  material is discarded, never fixed, never thrown (§46).
- Generatable exercise types narrowed to mcq / fillBlank / translation
  (§15 "where safe and supported").

### Added — generation prompts + parser
(`spine/content_prompt.dart`, `spine/generated_content_parser.dart`)
- §62-style SYSTEM/LANGUAGE-KNOWLEDGE/LEARNER-STATE/TASK prompt pair;
  the schema includes the honest `{"kind":"none"}` escape hatch so a
  model that cannot stay grounded declines instead of fabricating (§16).
- `GeneratedContentParser`: untrusted text → validated material via the
  same fence/prose-tolerant extractor the M4 planner uses; declines and
  rejections are typed Lefts.

### Added — bounded generated-content cache
(`data/generated_content_repository.dart`)
- Key `learn_profile_<iso>_gen` inside the M2 namespace (prefix reset
  covers it); newest-first, capped at 12 entries, 7-day freshness, the
  same corruption-safe contract as the profile/diagnostic/plan slots.

### Added — personalized content generator
(`data/personalized_content_generator.dart`)
- The §34 ladder for one concept: cached personalization (zero network)
  → ONE grounded Gemini call → validated write-through. Reuses the M4
  `PlannerTextClient` (one app-wide 15 RPM Gemini budget, §36); an empty
  excerpt refuses BEFORE any network call; cached AI material is
  re-validated before serving; every expected failure is a typed Left.

### Added — Smart Practice screen (`screens/smart_practice_screen.dart`)
- `/learn/smart` (auth-gated with the other Learn routes): today's plan
  focus with honest source labels, the trusted lesson + exercise-bank
  cards deep-linking into the EXISTING lesson/practice flows, three
  personalization chips, and inline rendering of generated material
  (explanation text, example/mini-dialogue lines, a practice-question
  preview runner). Urdu target text renders RTL (§48). The practice
  preview NEVER writes progress/XP — the trusted flow stays the only
  scorer; generated material is always labelled "Made for you · AI"
  (§63). Offline/decline/garbage states keep the trusted view (§46).
- `learn_content_providers.dart`: registry/repository/generator providers
  + the `SmartPracticeController` (trusted-first `prepare()` makes ZERO
  AI calls; `personalize()` is learner-triggered).
- `LearningPlanLike` gained additive per-activity parallel lists
  (concept anchors, kinds, reasons, difficulties) — M4 consumers
  unchanged.
- Learn screen gained the Smart practice entry card.

### Tests
- 6 new files: registry on real Hindi content (incl. stub honesty), the
  full validation matrix (wrong script, ungrounded, oversized, anchors),
  prompt assembly + schema honesty, cache contract (bounded, corruption,
  prefix reset), the generator flow (cache→AI→write-through, offline,
  decline, garbage) and the Smart Practice widget flow. Static suite:
  all checks PASS; `flutter test` remains a user-machine step.

### Preservation
- Byte-level diff vs M4 ZIP: additive only (new spine/data/provider/
  screen/test files) plus spine barrel exports, the plan-like additive
  fields, route registration, the entry card, this changelog and
  `docs/Learn-2.0/M5-Dynamic-Content.md`. A–G content, Exam Mode, VAN,
  AI chat, XP, achievements, streaks and signing untouched; no AI
  configuration = the trusted-only experience with zero network calls.

## [Learn Mode 2.0 — M4 Gemini AI Planner] - 2026-09-11

Fourth milestone: the heart of Learn Mode is live. The Gemini planner
now sits behind the M1 `LearningPlanner` contract, turning the
structured learner digest into a validated, grounded plan — and the
full Master Brief §36/§60 degradation chain is wired end to end:
AI plan → cached plan → deterministic → empty-but-valid. Additive only;
nothing existing replaced.

### Added — planner prompt assembly (`spine/planner_prompt.dart`)
- `buildPlannerSystemPrompt` (§62 pedagogy + strict JSON output schema,
  only build-supported activity kinds advertised) and
  `buildPlannerUserPrompt` with the three §62 sections: LANGUAGE
  KNOWLEDGE (trusted concept menu with mastery statuses — the only
  usable concept ids), LEARNER STATE (the M1 structured digest), TASK
  (session budget, repair-before-new).
- `extractPlanJson`: string-aware JSON extraction tolerant of markdown
  fences and prose; malformed output is a Left, never a crash.

### Added — AI output validation boundary (`spine/planner_output.dart`)
- `AiPlanParser`: untrusted model text → validated `LearningPlan`.
  Accepts the full-plan AND the §14 single-decision shapes; enforces
  every §14 rule (concept exists, language gate, supported activity
  type, difficulty 1..5, trusted lesson anchor, non-empty reason) by
  DROPPING invalid steps — never rewriting them. Dedupe per
  (concept, kind), cap 8, minutes clamped 1..30.

### Added — plan cache (`data/learn_plan_repository.dart`)
- Key `learn_profile_<iso>_plan` inside the M2 namespace (prefix reset
  covers it automatically); the same corruption-safe contract as the
  profile/diagnostic slots; 7-day freshness; legacy Sanskrit excluded
  by design.

### Added — Gemini planner + cached hop (`data/gemini_planner.dart`)
- `PlannerTextClient` / `GeminiPlannerTextClient`: planner-specific
  Gemini path (no persona pipeline, no prose moderation — the JSON
  contract is the boundary), 15 s timeout, conservative temperature.
- `GeminiPlanner`: unconfigured key short-circuits before any network
  call; every expected failure becomes a typed Left, never a throw;
  accepted plans are cached write-through (cache failure can never fail
  a good plan).
- `CachedPlanPlanner`: last good AI plan, honestly relabelled
  `PlanSource.cached`; empty / wrong-language / stale → Left so the
  chain continues.
- `learn_plan_providers.dart`: repository + text client + both planner
  providers; the text client SHARES the chat adapter's rate limiter —
  one app-wide 15 RPM Gemini budget (§36).

### Changed — provider wiring (`spine_providers.dart`)
- `learningPlannerProvider` now composes
  `ValidatingPlanner(delegate: gemini, fallback: ValidatingPlanner(
  delegate: cached, fallback: deterministic))` — the M4 swap M1
  reserved. Every consumer unchanged; every hop re-validates against
  the trusted graph.
- `LearningPlanLike` gained `source` (ai / cached / deterministic) for
  honest AI labelling (§63); UIs may show it, logic must not branch on
  it.

### Tests
- 6 new files: prompt assembly + JSON extractor matrix, §14 validation
  drops, plan-cache contract, planner failure typing + write-through,
  cached-hop honesty, and the full provider-wired chain walked hop by
  hop (ai → cached → deterministic, stale skip, garbage skip). Static
  suite: 100+ checks PASS; `flutter test` remains a user-machine step.

### Preservation
- Byte-level diff vs M3 ZIP: 11 added / 0 removed / 2 modified
  (spine barrel + planner wiring), plus this changelog and
  `docs/Learn-2.0/M4-AI-Planner.md`. A–G content, Exam Mode, VAN, AI
  chat, XP, achievements, streaks and signing untouched; offline
  behaviour identical to M1.

## [Learn Mode 2.0 — M3 Adaptive Placement + Diagnostic] - 2026-09-11

Third milestone: the placement game goes LIVE. VAN now invites every new
learner to a short, adaptive, game-like discovery round ("Discover your
level") seeded ONLY from trusted content, and the structured result
flows into the profile, the learning state, and the planner context —
additive only, nothing existing replaced.

### Added — diagnostic engine (`spine/diagnostic_engine.dart`, pure Dart)
- `DiagnosticItemBank`: trusted probe pools built from the concept graph
  + the existing exercise banks. Honest by construction — only
  dimensions the app can actually measure appear (script / practical /
  vocabulary / grammar / reading / sentence-formation for A–G;
  LISTENING is never scored — no audio exists — and comprehension is
  left unmeasured rather than faked, brief §11).
- `DiagnosticEngine`: the Master Brief §12 strategy for real — baseline
  probe first (seeded from the M2 self-report hint, never shown as a
  level), two consecutive correct → harder band, a miss → the NEXT
  probe is a true prerequisite (same dimension, nearest earlier
  concept), dimension rotation, and stop rules bounded to 8–16 probes
  (≈ the 3–7 minute budget). Deterministic per seed; retakes reshuffle.
- `DiagnosticAnswer` sealed hierarchy with correctness semantics pinned
  (by tests) to the practice engine's: display-permutation options,
  normalized free text, sequence compare, permutation matching.

### Added — placement session (`diagnostic_providers.dart`)
- `diagnosticItemBankProvider`, `diagnosticSessionProvider` (idle →
  active → feedback → finished / unavailable), `lastDiagnosticProvider`,
  `learnStateExtrasProvider`. One-way dependency graph: the spine
  watches the placement accessors; this file never imports the spine.
- Finish pipeline is persist-FIRST: result → state extras (review queue
  seeded with missed concepts, recent performance events per probe) →
  profile `currentLevel` → only then publish the finished state.

### Added — placement screen (`/learn/diagnostic`)
- VAN-led intro ("Let's see what you already know!"), three honesty
  bullets (3–7 minutes, adapts to you, no scores no judgement), friendly
  round meter ("Round 3 of about 12" — never a question number),
  encourage-first feedback beats with the real explanation, and a
  friendly result view built from `DiagnosticResult.friendlySummary()` —
  raw internal scores are never rendered (brief §11/§44).
- Safe states: no language → picker invitation; stub language (kn/ml/or)
  → honest "Not ready yet" unavailable state. Repeatable via "Play
  again" and the Learn/profile entry cards.

### Added — integration
- Learn screen: placement card in two states — "Discover your level"
  invitation (gated on a non-empty curriculum) and "Your path starts at
  {level}" with a quiet retake entry after placement.
- Profile screen: level-check card showing the friendly internal level
  name (no CEFR, no scores) or the invitation.
- Spine: `activeLearningStateProvider` merges the persisted review-queue
  / performance extras; `activePlannerContextProvider` carries the
  structured `DiagnosticResult` (§13 planner input) and exposes it in
  the digest for the M4 Gemini prompt.
- `DiagnosticResult.levelLabel` + additive `weakDimension` (threshold-
  honest variant: a perfect run no longer produces a fake "biggest
  opportunity" line; M1's `weakestDimension` contract unchanged).

### Tests
- 5 new test files (~40 cases): trusted item bank (real hi/bn content,
  honesty pins, reshuffle), adaptive engine (§12 strategy, stop rules,
  determinism, answer-checker parity with the practice engine, no raw
  numbers in summaries), repository diagnostic slot (round-trip,
  corruption, wrong-language guards, retake overwrite, clearAll
  coverage), provider/session wiring (perfect + struggling + retake runs
  end-to-end with persistence and spine pickup, stub-language
  unavailability), and the widget flow (intro, full happy path, feedback
  beat, unavailable state, no raw scores in the result view).

### Preserved
All A–G curricula, Exam Mode, VAN, AI chat stack, XP/streaks/
achievements, global UserProfile, onboarding, auth, signing — untouched
(byte-level diff vs the M2 ZIP: 8 additions + 7 allow-listed edits
only; `flutter test` remains a user-machine step as in M0–M2).

## [Learn Mode 2.0 — M2 Learner Profile + Goal System] - 2026-09-11

Second milestone: the learner model goes LIVE. The per-language profile
(goal, desired level, pace, practice style, self-report, daily goal) is
now persisted, wired into the planner context, and editable in a proper
VaaniX-styled screen — additive only, nothing existing replaced.

### Added — persistence (`learn_profile_repository.dart`)
- Namespaced per-language keys: `learn_profile_<iso>` (profile) and
  `learn_profile_<iso>_state` (review-queue/performance extras for
  M3/M6).
- Corruption-safe reads: missing / malformed / wrong-language values
  degrade to "unset" — never crash.
- Prefix-scoped `clearAll()` that can never touch Exam Mode or progress
  keys.

### Added — providers (`learn_profile_providers.dart`)
- `learnerProfileProvider(language)`: persist-FIRST-then-publish
  notifier with idempotent no-op saves and `resetToDefaults`.
- `learnerProfileConfiguredProvider`: has the learner actually saved a
  profile for this language (drives the Learn screen prompt).
- `activeLearnerProfileProvider`: the selected language's profile
  (null on the legacy Sanskrit path).

### Added — planner integration
- `activePlannerContextProvider` now carries the learner profile;
  session sizing follows the learner's own daily-goal minutes.
- `PlannerContext.toStructuredDigest()` exposes goal / desired level /
  pace / minutes as pure data — the M4 Gemini prompt consumes this.

### Added — profile screen (`/learn/profile`)
- Five sections in the existing design language: self-report, goal
  (all 8 brief options), desired level (clearly internal — no CEFR
  claims), pace, practice style, daily-goal chips (5–30 min).
- One explicit Save (partial edits never leak into planning), reset to
  defaults, safe empty state without a language.
- Entry points: Learn screen AppBar tune-action (per language) + a
  "Make it yours" prompt card that disappears once a profile is saved.
  The profile is always optional — defaults are honest.

### Added — spine: `SelfReport` (backward-compatible)
- `almostNothing / recognizeScript / understandBasics / conversational`
  with a coarse `suggestedLevel` hint. Deliberately NOT a level selector
  (brief §11): it seeds the M3 diagnostic difficulty. Pre-M2 profile
  JSON without the field loads unchanged.

### Tests
- 5 new test files: repository contract (round-trips, corruption,
  wrong-language guards, scoped cleanup), provider chain (persist-first,
  idempotence, isolation, configured flag, active profile), self-report
  model + backward compatibility, planner digest with profile data, and
  a full widget test of the profile screen (sections, save flow,
  pre-fill, empty state).

### Preserved
All A–G curricula, Exam Mode, VAN, AI chat stack, XP/streaks/
achievements, global UserProfile, onboarding, auth, signing — untouched
(byte-level diff vs the M1 ZIP: additions + the five allow-listed edits
only).

## [Learn Mode 2.0 — M1 Architecture Foundation] - 2026-09-11

First milestone of the Learn Mode 2.0 transformation: the architecture
spine is in place WITHOUT touching any existing behavior. Introduces the
concept-based learning model (Master Brief §9/§49/§63) beside the current
lesson-based engine, and fixes the one pre-existing wiring gap (G7).

### Added — Learn Mode 2.0 spine (`lib/features/learn/domain/spine/`)
- **mastery.dart**: MasteryStage lifecycle (introduced → practiced →
  understood → recalled → applied → mastered → maintained) + evidence-backed
  ConceptMastery records with JSON round-trip.
- **concept_graph.dart**: Language → Skill → Concept → Content graph derived
  deterministically FROM the existing curricula (one skill per chapter, one
  concept per lesson, order-faithful prerequisite chain). The graph is the
  trusted boundary future AI planning validates against.
- **learning_state.dart**: per-language evidence model (concept masteries,
  bounded review queue, rolling performance window) + `deriveLearningState`
  old→new mapping (completed/mastered lessons → honest stages only — no
  fabricated mastery).
- **learner_profile.dart**: goal / desired level / pace / practice style
  enums + LearnerProfile model (M2 wires persistence; clearly internal
  levels, never fake CEFR).
- **diagnostic.dart**: DiagnosticDimension/DimensionScore/DiagnosticResult
  contract + DiagnosticProbe spec + friendly summaries that never leak raw
  scores. The M3 placement flow builds on this.
- **learning_plan.dart**: ActivityKind (new/practice/review/repair/mastery
  check/challenge), LearningPlan, PlannerDecision + the §14 security gate:
  `PlannerDecisionValidator` rejects unknown concepts, language mismatch,
  unsupported activities, out-of-range difficulty, missing content.
- **evaluation.dart / learning_session.dart**: session + evaluation +
  mastery-update schemas (M6 consumes).
- **planner.dart**: `LearningPlanner` interface (replaceable provider —
  Gemini arrives in M4 behind the SAME contract) + `PlannerContext`
  structured learner state + `ValidatingPlanner` facade (drops ungrounded
  activities; falls back when AI fails or produces nothing valid).
- **deterministic_planner.dart**: offline, zero-cost planner implementing
  the proven ladder (weak repair → review → next unlocked concept) as
  grounded plans. Guarantees Learn Mode keeps working with AI unavailable.
- **spine.dart**: barrel export.

### Added — spine providers (`spine_providers.dart`)
activeConceptGraphProvider / activeLearningStateProvider /
activePlannerContextProvider / learningPlannerProvider — wired to the
EXISTING progress repositories (no new storage in M1).

### Fixed — G7: adaptive engine follows the ACTIVE language
- `adaptiveNextActionProvider`, `weakLessonsProvider` and
  `chapterBestFractionProvider` now derive from the active Learn Mode
  curriculum (per-language exercise counts via the dispatched bank) instead
  of the legacy Sanskrit curriculum.
- No language selected → unchanged legacy Sanskrit behavior (Exam Mode
  path byte-identical).
- New exam-existence guard: chapters WITHOUT quiz ids (all Learn Mode
  languages) can no longer trigger a phantom "Take the exam" action, and
  `allDone` now means "every lesson done" for them. Sanskrit (which has
  exams for every chapter) behaves exactly as before.

### Tests
- 6 new test files (`test/features/learn/spine/` + a G7 end-to-end chain
  test): real hi.json graph derivation, §14 decision validation matrix,
  evidence-only state mapping, deterministic planner grounding,
  hallucination filtering + AI-outage fallback, diagnostic summary without
  raw scores, and the language-aware CTA through the real provider chain.
- All pre-existing tests preserved (one helper extended to settle the new
  active-curriculum provider).

### Preserved
All A–G curricula and exercise banks, Exam Mode, VAN, AI chat stack, XP,
streaks, achievements, onboarding, auth, signing, docs — untouched.

## [Learn Mode Part G — Urdu Curriculum] - 2026-09-10

Ships the seventh Learn Mode language curriculum: 5-chapter / 20-lesson
Urdu course. Urdu uses the Nastaliq (Arabic) script written RIGHT-TO-LEFT
— the only RTL language in the VaaniX catalogue. Urdu has two grammatical
genders (like Hindi), three levels of 'you' (آپ/تم/تو), and rich
Persian/Arabic vocabulary that distinguishes it from Hindi.

### Urdu-specific features
1. Nastaliq script (RIGHT-TO-LEFT) — the only RTL language
2. 38+ letters with four joining forms (isolated/initial/medial/final)
3. Three levels of 'you': آپ (formal), تم (informal), تو (intimate)
4. Two grammatical genders: مذکر (m.) / مؤنث (f.)
5. نے (ne) past agent marker (split-ergative, like Hindi)
6. Postpositions: میں (in), پر (on), سے (from), کو (to), کا/کی/کے (of)
7. Eastern Arabic-Indic numerals (۰-۹)
8. Distinct kinship: اماں (mother), ابو (father), بھائی (brother), بہن (sister)
9. Persian/Arabic loans: پانی (water), روٹی (bread), سلام (greeting)
10. Cultural context: Pakistan, Ghalib, Iqbal, ghazals

### Preserved: Hindi (A), Bengali (B), Marathi (C), Telugu (D), Tamil (E),
Gujarati (F), Exam Mode, all other stubs, VAN, AI, signing.

## [Learn Mode Part F — Gujarati Curriculum] - 2026-09-10

Ships the sixth Learn Mode language curriculum: 5-chapter / 20-lesson
Gujarati course. Gujarati script has no top line (like Bengali), and
Gujarati has three genders (like Marathi). Present-tense verbs are
gender-neutral (simpler than Hindi).

### Gujarati-specific features
1. Gujarati script (no horizontal top line)
2. Three genders (masculine, feminine, neuter)
3. No gender in present-tense verbs (છું is same for all)
4. Distinct greeting: જય શ્રી કૃષ્ણ
5. નથી (present negation), મા (negative command)
6. -થી (from), -ને (to), -માં (in)
7. Distinct numbers: બે (2), ત્રણ (3), છ (6), નવ (9)
8. મમ્મી/પપ્પા kinship
9. Distinct vocabulary: પાણી, રોટલી, નમસ્તે

### Preserved: Hindi (A), Bengali (B), Marathi (C), Telugu (D), Tamil (E),
Exam Mode, all other stubs, VAN, AI, signing.

## [Learn Mode Part E — Tamil Curriculum] - 2026-09-10

Ships the fifth Learn Mode language curriculum: a substantial 5-chapter
/ 20-lesson Tamil course. Tamil is a DRAVIDIAN language (like Telugu),
with its own script, distinctive sounds, and a written vs spoken
diglossia that is explicitly taught.

### Added — Tamil curriculum
- **Curriculum asset** (`assets/curriculum/learn/ta.json`): 5 chapters,
  20 lessons with substantial Tamil content.
- **Exercise bank** (`tamil_exercises.dart`): 60+ exercises.
- **Provider extension**: now checks 6 exercise banks (Sanskrit, Hindi,
  Bengali, Marathi, Telugu, Tamil).

### Tamil-specific linguistic features respected
1. **Tamil script** (தமிழ் லிபி) — distinct, no horizontal top line
2. **Distinctive Dravidian sounds**: ழ (ḻa), ள (ḷa), ண (ṇa), ன (ṇa), ற (ṟa)
3. **No grammatical gender in verbs** (Dravidian feature)
4. **Three pronoun classes** (அவன்/அவள்/அது)
5. **Older/younger sibling distinction** (அண்ணன்/தம்பி, அக்கா/தங்கை)
6. **Written vs spoken diglossia** (செந்தமிழ் vs கொடுந்தமிழ்)
7. **Distinct postpositions**: -க்கு, -இல், -இருந்து, -உடன், -ஆல்
8. **Tamil numerals** (௦-௯) and distinct names (ஒன்று, ஐந்து, பத்து, நூறு)
9. **Distinct kinship**: அம்மா, அப்பா, அண்ணன்
10. **Distinct vocabulary**: சோறு (rice), நீர் (water), வணக்கம் (hello)

### Preserved (untouched)
- Hindi (A), Bengali (B), Marathi (C), Telugu (D): unchanged
- Other 5 languages: stubs unchanged
- Exam Mode, VAN, AI, progress/mastery/XP, signing: untouched

### Known limitations
- Flutter SDK not available in sandbox; tests must be run on user's machine

# Changelog

All notable changes to the VaaniX Flutter application.

## [Learn Mode Part D — Telugu Curriculum] - 2026-09-10

Ships the fourth Learn Mode language curriculum: a substantial 5-chapter
/ 20-lesson Telugu course. Telugu is a DRAVIDIAN language (not Indo-Aryan
like Hindi/Marathi/Bengali), with its own script, grammar, and vocabulary.

### Added — Telugu curriculum
- **Curriculum asset** (`assets/curriculum/learn/te.json`): 5 chapters,
  20 lessons with substantial Telugu content.
- **Chapter 1 (Level 0)**: తెలుగు లిపి — Telugu Script (5 lessons
  including the distinctive ళ consonant)
- **Chapter 2 (Level 1)**: శుభాకాంక్షలు మరియు పరిచయం — Greetings
- **Chapter 3 (Level 2)**: దైనందిన జీవితం — Daily Life
- **Chapter 4 (Level 3)**: వ్యాకరణం — Grammar (Dravidian, no gender)
- **Chapter 5 (Level 4)**: చదవడం — Reading

### Added — Telugu exercises
- **Exercise bank** (`lib/features/learn/data/telugu_exercises.dart`): 60+
  exercises with educational explanations, many in Telugu.
- **Provider extension**: `exercisesForLessonProvider` now checks Sanskrit,
  Hindi, Bengali, Marathi, AND Telugu exercise banks.

### Telugu-specific linguistic features respected
1. **Telugu script** (తెలుగు లిపి) — round, curved shapes, distinct
   from Devanagari and Bengali
2. **No grammatical gender in verbs** (Dravidian feature) — నేను వెళ్తాను
   works for any speaker, like Bengali but unlike Hindi/Marathi
3. **Three pronoun classes** (అతను/ఆమె/అది — he/she/it) — pronoun
   agreement but not grammatical gender
4. **Older/younger sibling distinction** — అన్న/తమ్ముడు (older/younger
   brother), అక్క/చెల్లెలు (older/younger sister)
5. **Inclusive vs exclusive 'we'** — మనము (inclusive) vs మేము (exclusive)
6. **Distinct postpositions**: -కి (to), -లో (in), -నుండి (from), -తో (with)
7. **Agglutinative morphology** — suffixes stack
8. **Telugu numerals** (౦-౯) — distinct from Devanagari and Bengali
9. **Distinct numbers**: ఒకటి (1), ఐదు (5), పది (10), వంద (100)
10. **Distinct kinship**: అమ్మ (mother), నాన్న (father), అన్న (older brother)
11. **Distinct vocabulary**: అన్నం (rice), నీళ్లు (water), నమస్తే (hello)
12. **No ने marker** for past-tense transitive verbs (unlike Hindi)

### Preserved (untouched)
- Hindi (A), Bengali (B), Marathi (C) curricula: unchanged
- Other 6 languages: stubs unchanged
- Exam Mode, Sanskrit curriculum, VAN, AI, progress/mastery/XP,
  achievements, onboarding, production signing: all untouched

### Added — Tests
- `telugu_curriculum_test.dart`: comprehensive integrity tests including
  Telugu-specific content checks (Telugu script not Devanagari, no-gender
  feature, older/younger sibling distinction, -కి/-నుండి/-లో postpositions,
  Telugu cultural context)
- Updated `learn_curriculum_dispatch_test.dart` and
  `active_curriculum_dispatch_test.dart` for Part D

### Known limitations
- Flutter SDK not available in sandbox; tests must be run on user's machine
- Telugu curriculum covers Levels 0-4; advanced fluency not claimed
- Audio not bundled

## [Learn Mode Part C — Marathi Curriculum] - 2026-09-10

Ships the third Learn Mode language curriculum: a substantial 5-chapter
/ 20-lesson Marathi course. Marathi uses Devanagari script (like Hindi)
but is a DISTINCT language with its own grammar, vocabulary, and cultural
context. This is NOT a Hindi translation.

### Added — Marathi curriculum
- **Curriculum asset** (`assets/curriculum/learn/mr.json`): 5 chapters,
  20 lessons with substantial Marathi content.
- **Chapter 1 (Level 0)**: देवनागरी लिपि — Devanagari Script (5 lessons
  including the distinctive ळ consonant)
- **Chapter 2 (Level 1)**: शुभेच्छा आणि परिचय — Greetings & Introductions
- **Chapter 3 (Level 2)**: दैनंदिन जीवन — Daily Life
- **Chapter 4 (Level 3)**: व्याकरण — Grammar (with 3-gender system)
- **Chapter 5 (Level 4)**: वाचन — Reading

### Added — Marathi exercises
- **Exercise bank** (`lib/features/learn/data/marathi_exercises.dart`): 60+
  exercises with educational explanations, many in Marathi.
- **Provider extension**: `exercisesForLessonProvider` now checks Sanskrit,
  Hindi, Bengali, AND Marathi exercise banks.

### Marathi-specific linguistic features respected
1. **THREE grammatical genders** (masculine, feminine, NEUTER)
   — Hindi has only 2; Marathi's neuter is distinctive
   - पुस्तक (book) is neuter in Marathi, feminine in Hindi
   - घर (house) is neuter in Marathi, masculine in Hindi
   - पाणी (water) is neuter in Marathi, masculine in Hindi

2. **Retroflex lateral ळ (ḷ)** — unique to Marathi among major Indian
   languages. Many Hindi words with ल become ळ in Marathi:
   - काल → काळ (time)
   - फल → फळ (fruit)
   - बाल → बाळ (child)

3. **Different pronouns**: तू/तुम्ही/आपण (vs Hindi's तू/तुम/आप)
   - Marathi also distinguishes inclusive (आपण) vs exclusive (आम्ही) 'we'

4. **Different number words**:
   - 6 = षण्ण (ṣaṇṇ) vs Hindi's छह
   - 100 = शंभर (śambhar) vs Hindi's सौ
   - 2 = दोन (don) vs Hindi's दो

5. **नाही at END of sentence** (Hindi's नहीं comes before verb)
   - मी जात नाही (Marathi) vs मैं नहीं जाता (Hindi)

6. **नको (nako)** — uniquely Marathi, covers 'don't want' AND 'don't do'

7. **Different postpositions**:
   - -हून for 'from' (Hindi uses से)
   - -ला for 'to' and time (Hindi uses को and बजे)
   - -मध्ये for 'in' (Hindi uses में)

8. **Distinct kinship**: आई (mother, vs Hindi माँ), बाबा (father),
   आजोबा/आजी (grandfather/grandmother — both sides, vs Hindi's
   paternal/maternal distinction)

9. **Distinct vocabulary**: भाजी (vegetable, vs Hindi सब्ज़ी),
   पोळी (flatbread, vs Hindi रोटी), नमस्कार (vs Hindi नमस्ते)

### Preserved (untouched)
- Hindi (Part A), Bengali (Part B) curricula: unchanged
- Other 7 languages: stubs unchanged
- Exam Mode, Sanskrit curriculum, VAN, AI, progress/mastery/XP,
  achievements, onboarding, production signing: all untouched

### Added — Tests
- `marathi_curriculum_test.dart`: comprehensive integrity tests including
  Marathi-specific content checks (ळ sound, 3-gender system, षण्ण/शंभर
  numbers, नाही/नको negation, Marathi cultural context)
- Updated `learn_curriculum_dispatch_test.dart` and
  `active_curriculum_dispatch_test.dart` for Part C

### Known limitations
- Flutter SDK not available in sandbox; tests must be run on user's machine
- Marathi curriculum covers Levels 0-4; advanced fluency not claimed
- Audio not bundled

## [Learn Mode Part B — Bengali Curriculum] - 2026-09-10

Ships the second Learn Mode language curriculum: a substantial 5-chapter
/ 20-lesson Bengali course. Bengali has its own linguistic identity
(no grammatical gender, three sibilants merged to /ʃ/, inherent vowel
/o/, না after verb) — this is NOT a Hindi translation.

### Added — Bengali curriculum
- **Curriculum asset** (`assets/curriculum/learn/bn.json`): replaced the Part 0
  stub with a full 5-chapter / 20-lesson Bengali course. Every lesson has
  substantial content with Bengali script, pronunciation notes, cultural
  context, and practice prompts. Content is embedded as UTF-8.
- **Chapter 1 (Level 0)**: বাংলা লিপি — Bengali Script (5 lessons:
  vowels, consonants, matras, barakhadi, conjuncts).
- **Chapter 2 (Level 1)**: শুভেচ্ছা ও পরিচয় — Greetings & Introductions
  (4 lessons: nomoskar, introductions, family, numbers).
- **Chapter 3 (Level 2)**: দৈনন্দিন জীবন — Daily Life (4 lessons: simple
  sentences/SOV, questions, negation, daily routine).
- **Chapter 4 (Level 3)**: ব্যাকরণ ও সংলাপ — Grammar & Conversation (4
  lessons: pronouns, tenses, postpositions, no gender).
- **Chapter 5 (Level 4)**: পঠন ও লেখন — Reading & Writing (3 lessons:
  conversations, reading paragraphs, cumulative review).

### Added — Bengali exercises
- **Exercise bank** (`lib/features/learn/data/bengali_exercises.dart`): 60+
  exercises across all 20 lessons, covering MCQ, fillBlank, matching, and
  translation types. Every exercise has an educational explanation, often
  in Bengali. Lesson IDs use the `bn_` prefix for global uniqueness.
- **Provider extension** (`exercise_providers.dart`):
  `exercisesForLessonProvider` now checks Sanskrit, Hindi, AND Bengali
  exercise banks. Backward-compatible.

### Bengali-specific linguistic features respected
- **No grammatical gender**: verbs, adjectives, and pronouns don't
  change by gender (unlike Hindi). আমি যাই = I go — same for any speaker.
- **Three sibilants merged**: শ, ষ, স all pronounced /ʃ/ (sh). The
  Sanskrit distinction is preserved in spelling only.
- **Inherent vowel /o/**: ক alone = 'ko' (not 'ka' like Hindi).
- **না after verb**: আমি যাই না (I don't go) — different from Hindi's
  नहीं before the verb.
- **No ने marker**: Bengali past tense doesn't use a subject marker
  for transitive verbs (unlike Hindi मैंने खाया → আমি খেলাম).
- **Locative case**: -এ/-য় (কলকাতায় = in Kolkata) — unique to Bengali.
- **Definite article**: -টা (ছেলেটা = the boy) — Hindi lacks this.
- **Bengali numerals**: ০-৯ distinct from Devanagari ०-९.
- **Distinctive kinship**: দাদা = older brother (not grandfather like
  Hindi दादा); ঠাকুরমা = paternal grandmother.

### Updated — Banner and dispatch
- **`_SelectedLanguageBanner`**: now recognizes both Hindi and Bengali as
  shipped languages, showing "Tap a chapter below to start learning
  Bengali." for Bengali selection.
- **Learn screen practice lookup**: now checks Sanskrit, Hindi, AND
  Bengali exercise banks.

### Preserved (untouched)
- Hindi curriculum (Part A): unchanged.
- All other Learn Mode languages (Marathi, Telugu, Tamil, Gujarati,
  Urdu, Kannada, Malayalam, Odia) — stubs unchanged.
- Exam Mode, Sanskrit curriculum, VAN, AI, progress/mastery/XP,
  achievements, onboarding, production signing — all untouched.

### Added — Tests
- `bengali_curriculum_test.dart`: schema/metadata, chapter structure
  (5 chapters ordered 0-4), lesson structure (20 lessons, all with
  content, bn_ prefix), content quality (Bengali script present, no
  Devanagari, no placeholders, no mojibake), exercise coverage, Sanskrit/
  Hindi isolation, level progression, Bengali-specific content checks.
- Updated `learn_curriculum_dispatch_test.dart` and
  `active_curriculum_dispatch_test.dart` for Bengali (Part B shipped).

### Known limitations
- Flutter SDK was not available in the build sandbox, so `flutter pub get`,
  `flutter analyze`, and `flutter test` were NOT executed before packaging.
- Bengali curriculum covers Levels 0-4 (script foundation through
  intermediate). Advanced fluency is NOT claimed.
- Audio is NOT bundled. Curriculum content is audio-ready.

## [Learn Mode Part A — Hindi Curriculum] - 2026-09-10

Ships the first real Learn Mode language curriculum: a substantial 5-chapter
/ 20-lesson Hindi course covering Devanagari script, greetings, daily life,
grammar, and reading. The Learn screen now dispatches between the legacy
Sanskrit Exam Mode curriculum and the per-language Learn curriculum based on
the learner's selected language.

### Added — Hindi curriculum
- **Curriculum asset** (`assets/curriculum/learn/hi.json`): replaced the Part 0
  stub with a full 5-chapter / 20-lesson Hindi course. Every lesson has
  substantial content (markdown-like text with Devanagari examples, tables,
  pronunciation notes, cultural context, practice prompts). Content is
  embedded directly in the JSON as UTF-8 — no Devanagari encoding issues.
- **Chapter 1 (Level 0)**: देवनागरी लिपि — Devanagari Script (5 lessons:
  vowels, consonants, matras, barakhadi, conjuncts).
- **Chapter 2 (Level 1)**: परिचय और अभिवादन — Greetings & Introductions
  (4 lessons: namaste, introductions, family, numbers).
- **Chapter 3 (Level 2)**: दैनिक जीवन — Daily Life (4 lessons: simple
  sentences/SOV, questions, negation, daily routine).
- **Chapter 4 (Level 3)**: व्याकरण और संवाद — Grammar & Conversation (4
  lessons: pronouns, gender/number, tenses, postpositions).
- **Chapter 5 (Level 4)**: पठन और लेखन — Reading & Writing (3 lessons:
  conversations, reading paragraphs, cumulative review).

### Added — Hindi exercises
- **Exercise bank** (`lib/features/learn/data/hindi_exercises.dart`): 60+
  exercises across all 20 lessons, covering MCQ, fillBlank, matching, and
  translation types. Every exercise has an educational explanation that
  teaches WHY an answer is correct (per the VaaniX feedback quality
  standard). Lesson IDs use the `hi_` prefix for global uniqueness.
- **Provider extension** (`exercise_providers.dart`):
  `exercisesForLessonProvider` now looks up lessons in BOTH the Sanskrit
  bank (`exercisesByLesson`) and the Hindi bank (`hindiExercisesByLesson`).
  Since lesson IDs are globally unique (`ls_*` vs `hi_*`), only one bank
  ever matches per lesson. Fully backward-compatible with the Sanskrit path.

### Added — Active curriculum dispatch
- **`activeCurriculumProvider`** (`curriculum_loader.dart`): a
  `FutureProvider<List<Chapter>>` that dispatches by the selected Learn
  language:
  - no selection → legacy Sanskrit `curriculumProvider` (4 chapters / 13
    lessons)
  - Hindi selected → `learnCurriculumProvider(hindi)` (5 chapters / 20
    lessons)
  - any other language → `learnCurriculumProvider(that language)` (empty
    until Parts B–J ship)
- **Learn screen wiring** (`learn_screen.dart`): now reads
  `activeCurriculumProvider` instead of `curriculumProvider`. The
  `_SelectedLanguageBanner` updates its message based on whether the
  selected language has a shipped curriculum (Hindi: "Tap a chapter below
  to start learning Hindi." vs other languages: "Curriculum in development
  — Parts B–J...").
- **Router wiring** (`app_router.dart`): `_LessonContentRoute` and
  `_ExerciseRoute` now read `activeCurriculumProvider` so lesson lookups
  work for both Sanskrit and Hindi lessons.

### Preserved (untouched)
- All other Learn Mode languages (Bengali, Marathi, Telugu, Tamil, Gujarati,
  Urdu, Kannada, Malayalam, Odia) — stubs unchanged, still return empty.
- Exam Mode: `assets/curriculum/v1.json`, `loadAllQuizQuestions`,
  `chapterQuizzes`, exam screen, quiz flow.
- Sanskrit curriculum: `sanskritCurriculum`, `sanskrit_lesson_content.dart`,
  `sanskrit_exercises.dart`, `unit2_lesson_content.dart` — all unchanged.
- VAN, AI, progress/mastery/XP, achievements, onboarding, production
  signing — all untouched.
- All Part 0 infrastructure: catalogue, picker, repository, providers —
  unchanged.

### Added — Tests
- `hindi_curriculum_test.dart`: schema/metadata integrity, chapter structure
  (5 chapters ordered 0-4), lesson structure (20 lessons, all with content),
  content quality (Devanagari present, no placeholders, no mojibake),
  exercise coverage (every lesson has exercises, every exercise is valid,
  every exercise has an explanation), Sanskrit isolation (hi_ prefix, no
  collision with ls_), level progression (chapters map to Levels 0-4).
- `active_curriculum_dispatch_test.dart`: no-selection returns Sanskrit,
  Hindi-selection returns Hindi curriculum, unshipped languages return
  empty, switching languages re-fetches reactively.

### Known limitations
- Flutter SDK was not available in the build sandbox, so `flutter pub get`,
  `flutter analyze`, and `flutter test` were NOT executed before packaging.
  The user must run these on their machine before extracting the next Part.
- The Hindi curriculum covers Levels 0-4 (script foundation through
  intermediate). Advanced fluency is NOT claimed — the architecture
  supports future Level 5+ additions.
- Audio is NOT bundled. Curriculum content is audio-ready (lesson content
  is plain text a future TTS layer can read), but no audio assets ship.

## [Learn Mode Part 0 — Foundation + Architecture] - 2026-09-10

Prepares Learn Mode for the 10-language curriculum without yet shipping any
language's content. This Part adds the catalogue, the picker, the per-language
curriculum dispatch path, and stub assets — Exam Mode, VAN, AI, achievements,
progress / mastery, onboarding, and production signing are all untouched.

### Added — Learn Mode language catalogue
- **Domain model** (`lib/features/learn/domain/learn_language.dart`): the
  `LearnLanguage` enum (10 values, locked), `LearnLanguageSpec` (code, native
  name, script name, ISO 639-1/2 codes, ISO 15924 script code, LTR/RTL
  direction, curriculum asset path), the `kLearnLanguageCatalogue` constant
  list, and lookup helpers `learnLanguageSpec` / `learnLanguageSpecByCode` /
  `learnLanguageSpecByName`. The locked 10-language list: Hindi, Bengali,
  Marathi, Telugu, Tamil, Gujarati, Urdu, Kannada, Malayalam, Odia. Urdu is
  the only RTL language (Nastaliq).
- **Persistence** (`lib/features/learn/data/learn_language_repository.dart`):
  `LearnLanguageRepository` over `ILocalStorageService`. Stores the selected
  language's enum name under `AppConstants.keyLearnLanguage` (a NEW key,
  distinct from `keyLanguage` which holds the UI language). Corruption-safe:
  an unknown stored value is treated as "no selection" instead of crashing.
- **Providers** (`lib/features/learn/presentation/providers/learn_language_providers.dart`):
  `learnLanguageRepositoryProvider`, `selectedLearnLanguageProvider` (reactive
  `StateNotifier`), `learnLanguageCatalogueProvider`, and
  `selectedLearnLanguageSpecProvider` (convenience accessor).
- **Constants** (`app_constants.dart`): `keyLearnLanguage` storage key and
  `learnCurriculumPath` (`assets/curriculum/learn/`).

### Added — Per-language curriculum dispatch
- **Loader extension** (`curriculum_loader.dart`): new
  `loadLearnCurriculum(LearnLanguage)` reads
  `assets/curriculum/learn/<code>.json`, validates the schema version, and
  returns the chapter list. Failure modes (asset missing, malformed JSON,
  future schema) all return an empty list rather than throwing — the picker
  stays alive and the Learn screen shows "curriculum in development" instead
  of an error.
- **Schema constant**: `kLearnCurriculumSchemaVersion = 1`. Bumped only on a
  breaking JSON schema change in `assets/curriculum/learn/`. Parts A–J ship
  content against schemaVersion 1.
- **Provider family**: `learnCurriculumProvider` (`AsyncNotifierProvider.family`)
  — distinct from the legacy `curriculumProvider` so the Sanskrit Exam Mode
  tree and the per-language Learn trees never share state. Selecting Hindi
  cannot load Bengali or Sanskrit.

### Added — Language picker UI
- **Route** (`route_names.dart` + `app_router.dart`): `/learn/language`
  (`learn-language`), nested under the Learn branch so back-nav returns to
  the lesson tree and the existing onboarding / auth guards still apply.
- **Picker screen** (`learn_language_selection_screen.dart`): 10 tiles, each
  showing the endonym in its own script (Devanagari, Bengali, Telugu, Tamil,
  Gujarati, Nastaliq, Kannada, Malayalam, Odia), the English name, the
  script name, and an RTL badge for Urdu. Currently selected language shows
  a check icon. Verbose semantic labels include name + script + direction +
  selection state. Tapping a tile persists the selection and routes back to
  `/learn`.
- **Learn screen integration** (`learn_screen.dart`): AppBar action opens the
  picker. A `_SelectedLanguageBanner` appears above the lesson tree when a
  language is selected, noting that the curriculum is in development (Parts
  A–J). The legacy Sanskrit tree stays visible underneath so no existing
  functionality is lost.

### Added — Per-language stub assets
- 10 JSON files under `assets/curriculum/learn/` (`hi.json`, `bn.json`,
  `mr.json`, `te.json`, `ta.json`, `gu.json`, `ur.json`, `kn.json`,
  `ml.json`, `or.json`). Each ships `schemaVersion: 1`, a `language` block
  mirroring the catalogue spec, and empty `chapters` / `quizzes` / `levels`
  / `vocabulary` arrays. The loader is exercised end-to-end for every
  language; Parts A–J replace each stub with real content.
- `pubspec.yaml`: declared `assets/curriculum/learn/` so the stubs bundle
  into the APK.

### Added — Tests
- `learn_language_catalogue_test.dart`: 10-language lock, uniqueness of
  codes / paths / native names, Urdu-only RTL, lookup helper behavior.
- `learn_language_repository_test.dart`: round-trip persistence, corrupt-value
  safety, key isolation from `keyLanguage`, provider reactivity.
- `learn_curriculum_dispatch_test.dart`: Part 0 contract (empty chapters for
  all 10), schema/asset integrity, Sanskrit legacy path preserved (4 chapters
  / 13 lessons / 32 quiz questions), provider isolation.
- `learn_language_selection_screen_test.dart`: 10 tiles render, native names
  render, tap persists selection + routes, check icon on selected, Urdu RTL
  badge, selection switch.
- `router_guard_test.dart`: extended to cover `/learn/language` as a protected
  nested route.

### Preserved (untouched)
- Exam Mode: `assets/curriculum/v1.json`, `curriculumProvider`,
  `loadAllQuizQuestions`, `chapterQuizzes`, exam screen, quiz flow.
- VAN: canonical expression art, `VanState` enum, `VanWidget`, controller,
  asset catalog, animations.
- AI: Gemini adapter, conversation pipeline, learning context, safety filter,
  offline tutor, rate limiter.
- Progress / mastery / XP / streaks / achievements: all repositories,
  notifiers, and providers unchanged.
- Onboarding, auth, settings, profile, home, progress screens: unchanged.
- Android production signing: `key.properties.example`, `build.gradle.kts`
  signing config, `AndroidManifest.xml` — untouched.
- All pre-existing tests: no edits beyond the one new assertion in
  `router_guard_test.dart`.

### Known limitations
- Flutter SDK was not available in the build sandbox, so `flutter pub get`,
  `flutter analyze`, and `flutter test` were NOT executed before packaging.
  The user must run these on their machine before extracting the next Part.
  All code was written against the verified Riverpod 2.5 / Flutter 3.6+
  APIs already used elsewhere in the codebase.

## [VAN Canonical Art Integration] - 2026-09-07

The externally supplied canonical VAN expression set is now the production
static visual for VAN. No VAN redesign: the artwork is displayed exactly as
supplied; only file names were normalised to semantic names (provenance in
`van_assets.json`).

### Added
- **Canonical expression layer** (`van_expression.dart`): `VanExpression`
  enum (neutral, thinking, happy, excited, motivating, confused, sleepy,
  achievement) and the deterministic `VanState` → expression mapping.
  No new states; priority/interruptibility untouched.
- **Expression catalog access** (`van_asset_catalog.dart`): `expressionFor`,
  `expressionForState`, `staticArtForState` with animation-first precedence —
  future Lottie assets will supersede static art without another migration.
- **Renderer support** (`van_visual_renderer.dart`): contain-fit canonical
  PNG rendering (proportions preserved, transparency kept, no crop), safe
  errorBuilder fallback to the Flutter painter.
- **Widget wiring** (`van_widget.dart`): canonical art renders without motion
  transforms (breathing/rotation/scale never reshape canonical art); static
  art is inherently reduced-motion safe; fallback painter + motion system
  unchanged for art-free catalogs.
- **Tests** (`van_expression_art_test.dart`): expression resolution, full
  state mapping, event → state → art for every wired production event,
  missing-asset fallback safety, reduced-motion behavior, semantics labels.

### Changed
- **pubspec.yaml**: declared `assets/van/expressions/` (master reference art
  intentionally not bundled).
- **van_assets.json**: schemaVersion 3, `expressions` section with per-file
  provenance, status `canonical_static_art_integrated`; animation entries
  unchanged and still pending art.
- **Accessibility**: VAN's semantics label now names the visible canonical
  expression ("Van — thinking", "Van — excited", …), replacing the verbose
  meaning-based label; no live region, no per-frame announcements.
- **Docs**: `docs/VAN/Implementation.md` documents the integrated layer.

## [V1 Final Completion] - 2026-09-06

The closing pass: the remaining accessibility gaps outside the earlier
a11y milestone, one coherent Sentry configuration, a branded not-found
route, a bounded AI retry layer, repository debt, and — most consequen-
tially — the Android build pipeline, which had never produced a binary.

### Accessibility (Phase 2 completion)
- **PrimaryButton**: the loading spinner previously REPLACED the label,
  so the button lost its accessible name and loading was silent. The
  label now stays visible beside the spinner and the spinner announces
  "Loading" (`primary_button.dart`).
- **VaaniXLoadingIndicator**: spinner carries its message as a
  semantics label.
- **SectionHeader**: the trailing action button keeps a 48dp touch
  target.
- **VaaniXTextField**: `MergeSemantics` associates the visible label
  with the field ("Email, edit box" instead of a bare edit box).
- **Live regions**: offline banner, auth error banner, chat error
  banner, exam explanation — dynamic failures are announced without a
  manual rescan.
- **Chat**: usage chip gained a tooltip, spoken severity ("plenty /
  running low / almost out") and a 48dp target; the typing indicator is
  a live region ("Van is typing…"); the usage-dialog bar is labeled.
- **Exam**: loading spinner and question progress carry labels; the two
  hardcoded `borderLight` defaults now branch on brightness (dark-mode
  fix).
- **Settings** dialogs and **Van personality** tiles expose the
  selected flag; **Learn** lesson tiles announce completed / not
  started and chapter progress bars are labeled; **Achievements** speak
  unlocked state and progress.
- **Home** tiles, `StatTile`, tappable `VaaniXCard`, `VanProfile`
  tiles: raw InkWells now advertise the button trait.
- **VanSpeechStrip**: inner Van semantics excluded (no duplicate
  announcements).
- New regression tests: `shared_widget_semantics_test.dart` (button
  traits, loading labels, retry classifier) — 21 accessibility tests
  total.

### Sentry (Phase 13 resolution)
- `SENTRY_DSN` now has ONE mechanism: a runtime dotenv variable
  (assets/env/.env — exactly what .env.example documents) with a
  `--dart-define` fallback for CI. `main()` loads the environment
  before `SentryFlutter.init`; `bootstrap()` skips a second load. Docs
  match code.

### AI (Phase 10)
- `GeminiModelAdapter` gained a bounded retry layer: transient failures
  (timeouts, network drops, 5xx / overloaded) retry up to 2x with
  500ms→1000ms backoff; invalid API keys, unsupported locations, 429 /
  quota, safety blocks and malformed requests NEVER retry. Streaming
  retries only before the first delta reaches the caller. Classifier
  pinned by unit tests.

### Navigation (Phase 15)
- Unknown routes render a branded `_NotFoundScreen` with a recovery
  route to Home (previously Flutter's default grey error page). The
  onboarding gate still wins for invalid deep links. Covered by
  `router_not_found_test.dart`.

### Android build (Phase 20) — fixed, was never functional
- `android/app/build.gradle.kts` did not compile (`java.util.Properties`
  vs the `java {}` extension accessor): the import is explicit now.
- Toolchain moved to Gradle 8.14 / AGP 8.11.1 / KGP 2.2.20 — Flutter
  3.47's enforced support floor — after the previously pinned
  Gradle 9.1 stack blew up Gradle's instrumentation transforms.
- Kotlin `jvmTarget` pinned to 17 to match `compileOptions` (fixes
  "Inconsistent JVM Target Compatibility").
- `ndkVersion` pinned explicitly (28.2.13676358); AGP's default-NDK
  fallback broke the Flutter plugin's synthetic native build (CXX1101).
- Verified: `flutter build apk --release` and `--debug` both produce
  installable APKs (arm64 target; com.vaanix.app, minSdk 24,
  targetSdk 36).

### Repository (Phases 1 / 22)
- Removed dead barrel files `lib/core/core.dart` and
  `lib/shared/shared.dart` (verified unreferenced).
- iOS bundle identifier aligned to `com.vaanix.app` (6 sites in the
  Xcode project) and display name unified to "VaaniX".
- Bootstrap `debugPrint` is `kDebugMode`-guarded; the defensive
  lesson-content fallback no longer says "Content coming soon!".


## [Accessibility Pass] - 2026-09-05

Screen-reader parity for every selectable control that communicated
state through COLOR ONLY. Visual design unchanged everywhere; only the
semantics tree gained the state a sighted user gets from fills, borders
and dimming.

### Changed
- **Practice option tiles (MCQ / fill blank)**
  (`exercise_screen.dart`): wrapped in `Semantics(button, selected,
  enabled, onTap)`; the option text carries the post-answer state
  ("correct answer" / "incorrect") that the green/red tile colors
  encode; the decorative letter badge is `ExcludeSemantics`.
- **Exam question options** (`exam_screen.dart`): same treatment —
  selected flag while choosing, disabled after answering, spoken
  correct/incorrect wording, tap action exposed.
- **Matching chips** (`exercise_screen.dart`): pending selection uses
  the standard selected flag; paired chips speak "already matched"
  (no semantics flag exists for that state) and disable; the opposite
  column announces a pairing hint ("Double-tap to match with …") while
  a left item is pending.
- **Ordering chips** (`exercise_screen.dart`): chosen items speak their
  sequence position ("Position 2 of 3: …") instead of relying on
  traversal order.
- **Exam setup** (`exam_screen.dart`): chapter tiles expose the
  selected flag; difficulty chips expose selected + enabled flags
  (empty bands announce "disabled" instead of only dimming); the bare
  question count reads as "N questions".
- **Onboarding selection cards** (`ob_goal_page.dart`,
  `ob_personality_page.dart`, `ob_subject_page.dart`): daily-goal,
  personality and class tiles expose `selected` + `button` + tap
  action; the class chip reads as "Class 7" instead of the broken
  "7 th"; decorative numerals excluded from the semantics tree.
- **Chat message copy** (`message_bubble.dart`): the long-press-to-copy
  gesture is now a semantics long-press action with a hint — screen-
  reader users can copy messages at all.
- **Test seam**: `exerciseSessionProvider` now reads its exercise bank
  through the existing `exercisesForLessonProvider` (same data source,
  behavioral no-op) so tests can drive matching/ordering exercises
  through the real screen.

### Added
- **Accessibility regression tests** (`test/accessibility/`):
  `onboarding_selection_semantics_test.dart` (selected flags + class
  naming), `exercise_option_semantics_test.dart` (MCQ
  selected/correct/wrong/enabled, matching pending/matched/hint,
  ordering position announcements),
  `exam_option_semantics_test.dart` (setup flags + question option
  state after submit). All assert real `SemanticsNode` flags, labels,
  hints and actions via `tester.getSemantics`.

### Verified untouched (already correct)
- Existing `Semantics` in shared widgets (Van widget, speech strip,
  streak/XP badges, progress meter) — preserved as-is.
- Analytics seam (`core/analytics`): typed, bounded, Noop in
  production, DebugPrint in debug — no change, no duplication.
- LearningContext chain: `learningContextProvider` → ChatController →
  `ConversationContext.learningContextFragment` →
  `DefaultPromptPipeline` → model adapters — wired and tested, no
  change.
- VAN state machine, event priorities, arbitration and fallback
  renderer — no change, no fabricated assets or events.
- Curriculum JSON, lessons, questions, answers, translations and
  chapter structure — byte-identical (diff-checked before commit).

### Verification
- `flutter analyze`: 0 issues (Flutter 3.47.2 / Dart 3.13.2).
- `flutter test`: 423 tests, 0 failures (409 existing + 14 new
  accessibility assertions across 8 test cases).
- `flutter build web --release`: success (compile verification; no
  Android SDK in the build environment, so APK/emulator runs were not
  possible — no verification was fabricated).

## [Phase 6] - 2026-09-05

Final production readiness. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 6 backlog; legacy snapshot
pollution note).

### Added
- **Android adaptive launcher icon** (API 26+): `mipmap-anydpi-v26`
  descriptor with the existing launcher art inset into the adaptive safe
  zone (foreground layers generated per density) over the app's light
  surface color (`@color/ic_launcher_background` = `#FAF8F4`, matching
  `AppColors.backgroundLight`). Legacy raster icons below API 26 unchanged.
- **Android release signing scaffold**: `build.gradle.kts` reads
  `android/key.properties` (gitignored) and signs release builds with the
  real keystore when present, falling back to the debug key otherwise so
  `flutter run --release` keeps working. Generation instructions live in
  the file header. The keystore itself remains an external owner item.
- **iOS `Podfile`** regenerated (platform 13.0, matching
  `IPHONEOS_DEPLOYMENT_TARGET` in `Runner.xcodeproj`): standard Flutter
  podhelper setup with the `RunnerTests` search-paths inheritance.
- **Resource-integrity regression tests**
  (`test/platform/platform_asset_refs_test.dart`): web manifest icons must
  exist with declared pixel sizes, `index.html` references must resolve,
  adaptive-icon layers must exist at all densities, `com/example` must
  stay deleted, the Podfile must pin platform 13.0, and the removed dead
  dependencies must stay out of `pubspec.yaml`.
- **`ExceptionMapper` matrix tests** (`test/core/exception_mapper_test.dart`):
  full retained mapping surface (Supabase auth branches, domain
  exceptions, timeouts, unknown fallback, Failure passthrough) pinned
  after the Dio branch removal.

### Changed
- **Android SDK levels pinned** in `app/build.gradle.kts`
  (minSdk 24 / targetSdk 36 / compileSdk 36 — Flutter 3.47 toolchain
  defaults made explicit) so toolchain upgrades cannot silently move the
  platform contract; stale `applicationId` TODO removed (identity is
  `com.vaanix.app`).
- **Web presence fixed and branded**: `manifest.json` now references the
  icons that actually ship (`Icon-maskable-192/512.png` — the template
  referenced `Icon-192/512.png` which were never committed), and
  name/description/theme colors use VaaniX branding instead of Flutter
  template defaults; `index.html` apple-touch-icon, title and meta
  description aligned.
- **`docs/Product/AI-Architecture.md` rewritten** — it contained a leaked,
  voice-transcribed developer prompt; it is now a real architecture
  document describing the implemented pipeline (safety → prompt → rate
  limit → cache → adapter), streaming semantics, bounds, personalization,
  grounding rules and the testing map.
- **`docs/VAN/Master-Van-Bible.md` filled** (was empty): master reference
  indexing the eight design chapters, the implemented event/state/cooldown
  system, the pending-art status and the no-fake-events rule.
- **`docs/Constitution/Constitution.md` de-duplicated** — every article was
  repeated 6–7 times (183 → ~60 lines, each article once); README status
  updated.
- **`docs/EngineeringCompletionReport.md` refreshed**: point-in-time body
  annotated, resolved `applicationId` blocker marked, and a Phase 0–6
  addendum added with the current phase/commit/test ledger.

### Removed
- **`Archive/`** (four historical project copies, 267 tracked files,
  2.3 MB) — deleted from the working tree; content preserved in git
  history. Analyzer exclusion entry retired with it.
- **Dead infrastructure**: the standalone Dio stack
  (`dio_client.dart` + auth/refresh-token/logging/retry interceptors —
  nothing ever constructed a `DioClient`; HTTP transport lives in the
  Gemini adapter and Supabase clients), `NavigationService` (its provider
  was never watched; `navigator_keys.dart` stays — the router owns
  `rootNavigatorKey`), and `core/providers/app_state.dart`
  (`globalLoading`/`appInitStatus`/`FeatureFlags` — never consumed). The
  `ExceptionMapper` Dio branch, the core barrel exports and the stale
  logger example were updated accordingly.
- **Dependencies** `dio`, `cached_network_image`, `flutter_svg` (zero
  imports across lib/ and test/).

### Verification
- `flutter analyze`: 0 issues.
- `flutter test`: 415/415 (387 + 28 new).
- `assets/curriculum/v1.json` untouched (content freeze respected).

## [Phase 5] - 2026-09-05

UI/UX + product polish. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 5 backlog; rows A, J, L;
defects #10, #17).

### Fixed
- **Route-guard gap (defect #17)**: `/chat` and `/achievements` are
  pushed on top of the shell and were missing from the protected-route
  set — with Supabase configured, a deep link straight to either screen
  bypassed the auth gate every other screen honors. Both are protected
  now, and the match is prefix-aware so nested sub-routes (e.g.
  `/learn/lesson/:id/practice`) cannot slip through either. The redirect
  decision was extracted into pure, `@visibleForTesting` functions
  (`guardRedirect` / `isProtectedLocation`) so the full gate matrix
  (onboarding × auth × every route family, offline vs backend) is pinned
  by tests.
- **Onboarding page-count drift (defect #17)**:
  `AppConstants.onboardingScreenCount` claimed 7 (the PRD §8.1 screen
  count including the splash) while the flow hosts 6 pages — and the
  constant was never referenced, with `6` hardcoded in two places. The
  constant now reads 6, carries a doc explaining the splash distinction,
  and both the notifier clamp and the screen's dot indicators derive
  from it (single source).
- **Onboarding restart lost progress (row A)**: a mid-onboarding app
  restart dropped the learner back to page 0. The last page index is now
  persisted on every move, hydrated on restart (clamped against the
  page count to defend against stale values), ignored once onboarding
  completed, and cleared on completion so no stale index survives.
- **"Reset to default" was mislabeled (row J)**: the Van Profile button
  forced `PersonalityMode.cheerleader` — the first option in the picker,
  not a default — and once a mode was chosen there was NO way back to
  the un-personalised state (`copyWith` cannot null a field out). A real
  clear path now exists: `UserProfileRepository.clearPersonalityMode()`
  removes the storage key, and the notifier rebuilds the state with a
  null mode (identity fields kept). Van returns to his default greeting,
  Settings shows "Not set", and the choice stays re-selectable.
- **Dark-mode contrast defects (row L, a11y/dark sweep)**: 20+
  user-visible elements used light-theme-only `AppColors` tokens
  unconditionally, washing out or disappearing in dark mode — chat
  usage-dialog body text, typing-indicator dots, Van-bubble timestamps,
  chat input hints, onboarding inactive page dots, onboarding name/auth
  copy and "or" divider, subject/goal card borders and icon tints, exam
  filter-chip borders, progress chevrons, locked-achievement icon tints,
  auth screen copy, the exercise screen's `?? Colors.white` card
  fallback, and the Van profile personality tiles. All now resolve the
  themed token per brightness. The Settings screen's redundant nested
  brightness ternary (dead inner branch) was collapsed.

### Changed
- **Mojibake sweep final pass (defect #10)**: the last corrupted byte
  sequence (`â†'` for `→`) in `app_router.dart`'s NavigationService doc
  comment is fixed. A full-codebase re-verification (grep signatures +
  UTF-8 validation of every .dart file) confirmed the string-level
  mojibake flagged in the audit was already cleaned in earlier phases —
  the remaining flagged sites were legitimate em-dash typography.
- **Accessibility sweep (row L)**: every icon-only `IconButton` now
  carries a tooltip/semantic label (password visibility toggle, chat
  error dismiss, send, onboarding back + name clear, lesson/practice
  back, matching remove-match). The onboarding back button's tap target
  is held at the 48px Material minimum (M3's default is 40px, its icon
  is 20px).

### Tests
- 29 new tests: `test/app/router_guard_test.dart` (10 — full guard
  matrix incl. the /chat//achievements regression), 
  `test/features/onboarding/onboarding_page_persistence_test.dart`
  (12 — persist/hydrate/clamp/clear/no-op-move/constant), and
  `test/features/profile/personality_reset_test.dart` (7 — repo clear,
  notifier state rebuild, identity fields kept, storage key removed,
  survives reload). Suite: 387 passed (was 358).

## [Phase 4] - 2026-09-05

AI tutor + learning intelligence. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 4 backlog).

### Added
- **Streaming replies are live**: the previously dead `pipeline.stream`
  path (fully built, never called — audit row I) is now wired into the
  chat controller behind the existing `AiConfig.enableStreaming` flag
  (production default ON). Deltas render into the trailing message bubble
  in place, so Van's reply grows while it is generated — a real win on
  slow connections and for the offline tutor's word-by-word cadence.
  Success drives the identical Van speaking lifecycle, achievement check
  and usage-chip refresh as the complete path; `enableStreaming: false`
  still routes through `send()` (pinned by tests).
- **Honest streaming failure semantics**: a failed stream withdraws the
  partial bubble (the pipeline persists nothing on failure — UI and
  memory stay consistent), a stream that ends with no content surfaces an
  error instead of a fabricated empty success, and an unsafe ASSEMBLED
  reply is re-checked with the same SafetyFilter the pipeline uses, so
  text that would not be persisted is never left dangling on screen.
- **Learner display name (personalization)**: `UserProfile.displayName`
  (Settings → LEARNING PROFILE → "Your Name", editable + clearable) is
  persisted through the profile repository and flows into
  `LearnerContext.displayName` — the Gemini persona addresses the learner
  by name and the offline tutor's greetings personalize (`_greet(name)`)
  instead of the previous hardcoded `''`. Empty = anonymous by design.
- **`dailyUsageProvider`**: today's AI usage is a watched FutureProvider;
  the ChatController invalidates it after every successful turn.

### Fixed
- **Stale usage chip (defect #16)**: the Chat screen's remaining-quota
  chip read the tracker exactly once per screen build via a
  `FutureBuilder` and never refreshed — it now watches
  `dailyUsageProvider` and updates immediately after each send.
- **Settings reset missed the AI subsystem (defect #9)**: Reset Progress
  now also clears persisted conversations (`clearAll`), the response
  cache and the token-usage history (whose `clear()` documented "used by
  Settings → reset" but was never called), and invalidates the chat
  controller + usage chip so the UI reflects it instantly. The reset
  dialog copy says so.
- **Per-turn context no longer churns the Gemini system instruction**:
  the bounded learning snapshot was embedded in the persona/system
  instruction, forcing a `GenerativeModel` rebuild on EVERY request
  (client caching defeated). The persona is now stable across turns and
  the snapshot travels as framed per-turn message content
  (`ConversationContext.learningContextMessage`, header/footer markers in
  `AppConstants`), appended by the adapter to the outgoing user turn —
  the model client is reused for the adapter's lifetime.
- **Duplicated outgoing turn in Gemini history**: the request history was
  built from the full transcript INCLUDING the last user message, which
  was then sent again via `sendMessage` — the model saw every new message
  twice. `buildRequestHistory` now excludes the outgoing message.
- **Bounded AI transcripts (defect #12)**: persisted conversation
  transcripts are capped at `AppConstants.maxAiTranscriptMessages` (100,
  newest kept); conversation KEYS are pruned to the newest
  `maxStoredAiConversations` (5) by the `conv_<millis>` timestamp
  (timestamp-less legacy ids sort oldest); and `clear()` now REMOVES the
  storage key instead of writing an empty-list zombie. The
  `ai_conversation_` prefix lives in a single constant.

### Tests
- 358 tests passing (334 existing + 24 new): progressive rendering +
  failure/empty/unsafe withdrawal semantics, streaming Van lifecycle,
  usage-provider invalidation, display-name stamping, mid-stream dispose
  safety; transcript cap sliding window, key removal, conversation
  pruning (newest-kept, current-never-pruned, legacy-ids-first); Gemini
  request shaping (history excludes outgoing turn, sanitizer applied,
  stable instruction across turns, framed context message); Settings
  reset widget test driving the REAL flow (AI keys cleared, identity
  kept); display-name persistence round-trip. The learning-context
  pipeline tests were re-pinned to the new stable-persona contract, and
  the race/speaking controller tests now explicitly pin the complete-turn
  path while production defaults to streaming.

## [Phase 3] - 2026-09-05

VAN experience completion. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 3 backlog).

### Added
- **The four dead VAN events are now dispatched** (previously declared with
  mapped reactions but never sent):
  - `streakExtended` — dispatched by the Nest after a genuine streak
    extension (day N card: "N-day streak — wonderful consistency!").
  - `onboardingCompleted` — dispatched at the nest reveal, so the
    controller-driven Van on Home greets the freshly onboarded learner.
  - `aiResponseFinished` — dispatched by the chat controller when a reply's
    reading window elapses. The speaking reaction no longer hard-cuts at
    its 2.2 s state default: the reply's window is passed via the new
    `VanEvent.displayDuration` (base 2200 ms + 24 ms per extra word,
    capped at 6 s), and the completion signal settles Van for real.
  - `userIdle` — decision recorded: **intentionally NOT dispatched in V1**
    (no genuine idle detector exists; a synthetic timer would fabricate
    companion behavior). The enum value stays reserved with settle-only
    semantics documented in `van_event.dart`.
- **Reaction cooldown**: `VanController` now honors the previously unused
  `AppConstants.vanIdleCooldownMs` (30 s) as a per-event-type cooldown for
  system-initiated companion-life reactions (`appOpened`,
  `streakExtended`, `onboardingCompleted`) — Home re-entry no longer
  re-greets over and over, and same-frame celebrations cannot stack.
  Deliberately ungated: per-answer task feedback, `companionTapped` play,
  milestone celebrations, and the whole AI/error lifecycle. The cooldown
  and clock are injectable for tests.
- **van_assets.json is the single catalog source**: the VAN animation
  catalog loads from `assets/van/metadata/van_assets.json` via the new
  `loadVanAssetCatalog()` loader + `vanAssetCatalogProvider` (Dart
  `VanAssetCatalog.v1` demoted to a malformed-asset fallback, same pattern
  as the curriculum loader). A parity test pins JSON ↔ Dart equality and
  one-visual-per-state coverage.
- **VanSpeechStrip wired** at its designed "exam preparation" surface:
  the exam instructions screen now opens with Van's encouragement strip
  (the widget existed but was never used).

### Fixed
- **Multi-achievement bursts consolidated**: the practice and exam screens
  dispatched one `achievementUnlocked` reaction AND one snackbar per
  achievement — bursts of non-interruptible celebrations that arbitration
  silently dropped, plus stacked snackbars. Both surfaces now emit a
  single consolidated celebration (first achievement + "(+N more)") for a
  batch, matching the lesson screen pattern.
- **VAN ticker pauses when offscreen**: the breathing motion controller
  used to tick forever. `VanWidget` now stops the ticker inside disabled
  `TickerMode` subtrees (covered/offstage routes, hidden tab children) and
  while the app is backgrounded (lifecycle paused/hidden), resuming from
  the stopped phase. The widget state is public (`VanWidgetState`) with a
  test-visible `motionController` getter.

### Tests
- 334 tests passing (314 existing + 20 new): JSON↔Dart catalog parity +
  loader fallback, per-type cooldown semantics (gated/ungated matrices),
  `displayDuration` fallback-clock behavior, ticker pause/resume under
  `TickerMode` and app lifecycle, chat reading-window units + full
  speaking→finished→idle lifecycle, consolidated exam achievements
  (updated exam journey to the new one-snackbar contract).

## [Phase 2] - 2026-09-05

Learning / practice / exam / adaptive completion. Full audit basis:
`docs/Audits/V1-Audit-Phase0.md` (§5 Phase 2 backlog).

### Added
- **Single source of truth for the exam bank**: the question bank now loads
  from the JSON curriculum asset (`assets/curriculum/v1.json`) via the new
  `loadAllQuizQuestions()` loader. The compiled-in Dart bank
  (`chapterQuizzes`) is demoted to a malformed-asset fallback — exam
  content is byte-identical (pinned by a JSON↔Dart parity test). The exam
  session (`examQuizProvider`) became an async family so the bank load
  settles with a visible loading state instead of reading the hardcoded
  map; the pure `QuizNotifier` engine is unchanged and reused by the new
  controller (no logic drift).
- **Adaptive maps from the same source**: `quizIdCatalogProvider` and
  `quizIdsByChapterProvider` derive every quiz id from the JSON bank, so
  the exam flow and the adaptive engine can never drift apart. The dead
  `loadQuizForChapter`/`chapterQuizProvider` pair was removed.
- **Practice-session resume**: an in-progress practice session is
  snapshotted to storage after every state change (index, score, mastered
  ids) and restored on screen entry with a visible "picked up where you
  left off" cue. An app kill or accidental back-swipe no longer restarts
  practice from question 1. Fresh or finished sessions expire the
  snapshot; a full progress reset purges all `exercise_session_*` keys.
- **Attempt-history cap**: per-quizId attempt history is now capped at
  `AppConstants.maxAttemptsPerQuiz` (20) with the all-time best attempt
  ALWAYS retained — repeated retakes can no longer grow storage without
  bound, and best-score displays stay correct for the install lifetime.

### Fixed
- **Best-score display**: a chapter attempted with a 0% best was reported
  as "Exam not attempted" on the Progress screen (the provider dropped
  best == 0.0 entries, conflating "attempted with 0%" with "never
  attempted"). Attempted chapters now always appear; the exam result view
  likewise shows the real best (even 0/total) once any attempt exists.
- **Controller mutated during build**: the practice screen synced its
  translation `TextEditingController` and matching-chip state inside
  `build()` — moved into post-build `ref.listen` callbacks.
- The exam setup/instructions screens read the chapter list from the
  async JSON curriculum (Dart fallback retained) instead of the compiled
  constant.

### Tests
- 314 tests passing (293 existing + 21 new): JSON↔Dart bank parity,
  adaptive catalog derivation, async exam session (selection / restart /
  empty-config), attempt-cap trimmer + repository-level cap with
  best-preservation, session-snapshot reset purge, 0%-attempted chapter
  display, exercise resume engine + widget resume/persist/expire flows.

## [Phase 1] - 2026-09-05

Core student product loop repairs. Full audit basis: `docs/Audits/V1-Audit-Phase0.md`.

### Fixed
- **Build blockers**: `chat_screen.dart` re-encoded as valid UTF-8 (raw CP1252
  bytes made Dart treat the file as binary, breaking the router import);
  `CardTheme`/`DialogTheme` replaced with `CardThemeData`/`DialogThemeData`
  in `app_theme.dart` (4 sites) — `flutter analyze` is now clean on modern
  stable toolchains.
- **Exam autosave**: finishing a quiz now persists the attempt, XP and the
  achievement check automatically. The previous manual-only Save button
  meant an app kill on the result screen silently lost the result. The Save
  button remains as visible confirmation + retry path, with an honest label
  (no XP promised on repeat completions).
- **Achievement bonus XP ledger**: bonus XP no longer flows through
  `completeLesson()` with synthetic `ach_*` lesson ids, which inflated
  lesson counts, journey % and the adaptive subtitle. New idempotent
  `awardBonusXp` repository API backed by a dedicated ledger; legacy
  polluted lesson-id lists are sanitized on startup.
- **Streak achievements**: Home now runs the achievement checker after
  recording daily activity, so 3-day / 7-day streaks unlock from streak
  activity alone. A failed streak write no longer stamps a false
  `lastActiveDate`.
- **Practice completion**: a persistence failure no longer leaves the
  complete button permanently disabled with no feedback (try/catch/finally
  + error snackbar, mirroring the lesson-content pattern).
- **Lesson completion ordering**: the reactive completed-lesson list now
  commits only after a successful repository write (previously optimistic,
  leaving stale in-session state on failure).
- **QuizNotifier**: an empty question bank now fails with a clear
  `StateError` instead of a confusing `clamp()` ArgumentError.
- **Mojibake**: corrupted em-dash characters fixed in user-visible strings
  (exam feedback, onboarding copy) and section-banner comments.

### Changed
- Analyzer now excludes `Archive/**` (historical snapshots) so `flutter
  analyze` reflects the real project.
- Pubspec SDK floor raised to Dart >= 3.6.0; README documents the verified
  toolchain (Flutter >= 3.32, tested on 3.47.2).
- Transitive dependency refresh from `flutter pub get`.

### Tests
- 293 tests passing (282 existing + 11 new): exam autosave E2E, bonus-XP
  ledger, legacy sanitize, streak achievement trigger, streak-write failure
  isolation, lesson-completion rollback, empty-bank guard.

## [5.0.0] - 2026-07-30

### Added
- Complete Clean Architecture restructure (app/core/features/shared layers)
- Core auth abstraction (`CoreAuthRepository`, `AuthSession`, `AuthUser`) in `core/auth/`
- `SessionManager` with dependency inversion (core owns the contract, feature supplies impl)
- `NavigationService` for context-free programmatic navigation
- `ConnectivityService` with reactive online/offline providers
- `DioClient` with auth, logging, and retry interceptors (exponential backoff + jitter)
- `ILocalStorageService` abstraction with typed SharedPreferences implementation
- `AppLogger` structured logging facade (debug → prod stub ready)
- `AppLifecycleObserver` reactive provider
- Full Material 3 theme system (light + dark) with `ThemeNotifier`
- `FeatureFlags` gating for unfinished modules
- Complete onboarding flow (6 pages: name, personality, subject, goal, auth, nest reveal)
- Splash screen with animated logo and routing decision
- Auth screen (Google + Phone UI, wiring ready)
- Home screen (The Nest) with Van companion, streak/XP badges
- Settings screen with theme toggle and learning profile display
- 14 shared widgets (VaaniXCard, VanWidget, PrimaryButton, etc.)
- String, DateTime, BuildContext, Int extension methods
- `go_router` with `StatefulShellRoute` and declarative redirect guards
- `.gitignore` covering Flutter, secrets, IDEs, and generated files
- `.env` untracked from git history

### Changed
- All imports converted to `package:vaanix_app/...` (zero relative imports)
- `core/config/` renamed to `core/environment/`
- `core/bootstrap/` moved to `app/bootstrap/`
- `core/router/` moved to `app/router/`
- `core/utils/logger.dart` moved to `core/logging/`
- `core/utils/app_lifecycle_observer.dart` moved to `core/lifecycle/`
- `core/providers/navigation_service.dart` moved to `core/navigation/`
- `core/utils/extensions.dart` moved to `shared/extensions/`
- Documentation folders consolidated under `docs/`
- Old code versions archived to `Archive/`

### Removed
- Unused dev-dependencies: `freezed`, `json_serializable`, `build_runner`, `riverpod_generator`, `riverpod_annotation`
- `assets/env/.env` from Flutter asset declaration
