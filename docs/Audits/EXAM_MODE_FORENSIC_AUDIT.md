# VaaniX Exam Mode 2.0 — Forensic Audit (M0)

**Project:** VaaniX-Core-FINAL (supplied ZIP, 2026-09 build)
**Scope of audit:** entire repo — lib/, assets/, data, services, providers, models, widgets, screens, tests, Android/, iOS/, web/, pubspec, routing, state management, AI pipeline, Learn Mode, Exam Mode, VAN, gamification, offline, analytics, storage — plus the six official CBSE syllabus PDFs supplied for 2026–27.
**Method:** direct source inspection of all 197 Dart files' headers and key implementations, 108 test files, pubspec/asset manifest, router/guard logic, AI stack, progress/gamification domain, Learn-2.0 spine, and full text+OCR extraction of all six PDFs (embedded text layers are font-damaged for Devanagari conjuncts; every load-bearing string was re-verified by 200–400 DPI rasterization + Tesseract `hin`/`san` OCR — see M1 Ingestion Report).

---

## 1. Executive Summary

VaaniX today is a **Sanskrit-first Learn Mode app with a working but primitive Exam Mode**. The Learn Mode is genuinely mature (multi-language curriculum, sessions, adaptive next-action engine, diagnostic screen, spine architecture with learner profile/mastery/planner). The Exam Mode is a single-screen chapter+difficulty quiz over a 20-question JSON bank tied to the **Learn curriculum** (Sanskrit alphabet/greetings chapters) — it has **no CBSE syllabus grounding, no course/board identity, no exam scope selection, no exam profile, no diagnostic, no AI planner, no PYQ/mock system, and no syllabus data layer at all**.

The transformation required by the master plan is therefore a **build-out, not a rewrite**: the existing engine pieces (QuizNotifier, progress persistence, VAN event bus, Gemini adapter with rate-limit/cache/retry/fallback, offline tutor, gamification, router guards) are reusable foundations. The missing pieces are the syllabus authority layer (M1), the exam-mode UX and profile (M2–M3), the adaptive diagnostic (M4), the planner (M5), and the evaluation/weak-area/mock systems (M6–M9).

**Verdict per the master plan's "preserve what works" rule:** preserve Learn Mode, VAN, gamification, AI stack, design system, offline systems. Extend the exam feature in place. Do not delete or rewrite anything that currently passes tests.

---

## 2. Architecture Map (CURRENT)

| Layer | Location | Status | Notes |
|---|---|---|---|
| Bootstrap | `lib/app/bootstrap/app_bootstrap.dart` | ✅ works | dotenv, Supabase init, Sentry no-op mode |
| Router | `lib/app/router/app_router.dart` | ✅ works | go_router 14, onboarding + auth gates, redirect logic is pure & unit-tested |
| State | Riverpod 2.5 (codegen-free) | ✅ works | consistent `NotifierProvider`/`FamilyAsyncNotifier` patterns |
| Theme | `lib/core/theme/` | ✅ works | Poppins-bundled, Material 3, `AppTextStyles.sanskritBody` renders Devanagari correctly |
| Storage | `lib/core/storage/local_storage_service.dart` | ✅ works | SharedPreferences wrapper; keys for onboarding, XP, attempts |
| Auth | `lib/features/auth/` + Supabase | ✅ works | offline/noop repository when unconfigured |
| AI | `lib/features/ai/` (4.6k LOC) | ✅ works | GeminiModelAdapter (timeout, 2-retry transient policy, rate limiter 15 RPM, response cache, token tracker, SafetyFilter in/out), OfflineModelAdapter + OfflineTutor fallback, conversation memory, chat screen |
| Learn Mode | `lib/features/learn/` (~29k LOC) | ✅ works | 10-language JSON curricula, spine: LearnerProfile/LearningState/mastery/mastery_scheduling/DeterministicPlanner/diagnostic_engine/session_engine/content_registry/generated_content |
| Exam Mode | `lib/features/exam/` (1.4k LOC) | ⚠️ partial | Single screen: chapter → difficulty → deterministic quiz → result → autosave attempt. Grounded only in Learn's Sanskrit curriculum |
| Progress | `lib/features/progress/` | ✅ works | XP (idempotent per quiz id), streak, attempts history, milestones, adaptive NextAction engine, daily goals |
| VAN | `lib/features/van/` | ✅ works | event bus → expression state machine; asset catalog; canonical artwork |
| Gamification | achievements, milestones, XP | ✅ works | achievement checker wired to exam events |
| Analytics | `lib/core/analytics/` | ✅ works | event log (console/Sentry-ready) |
| Connectivity | `lib/core/network/connectivity_service.dart` | ✅ works | offline awareness exists |
| Assets | `assets/curriculum/` | ✅ works | v1.json (3 Sanskrit chapters, 20 quiz questions), learn/<lang>.json × 10 |

---

## 3. Exam Mode — Detailed Current State

**Files:** `exam_screen.dart` (1,146 lines), `quiz_providers.dart` (214 lines). That is the entire feature.

**What exists and works (all tested):**
- `ExamConfig` (chapterId + difficulty) → stable `quizId` → attempt history + XP idempotency.
- `selectExamQuestions` deterministic filter/sort — reproducible attempts.
- `QuizNotifier` pure engine (select/submit/next/restart) with mirror into Riverpod `AsyncValue`.
- Result view with score/accuracy, autosave via `progressRepositoryProvider` (manual save kept as retry path).
- VAN events on quiz start/correct/wrong/perfect/completion; analytics events; achievement checks.
- 4 exam test files: grounding test (JSON↔Dart parity), single-source bank, selection determinism, full flow widget test, option semantics accessibility test.

**What is missing vs. the Exam Mode 2.0 target (the whole product vision):**

| # | Gap (from master plan) | Current state | Required |
|---|---|---|---|
| G1 | Board → Class → Subject → Course flow | Nothing — exam screen is board-less | M2 selection flow + `BoardProvider` abstraction (board-agnostic engine, CBSE first) |
| G2 | Official verified syllabus (6 PDFs) as source of truth | **No syllabus data exists anywhere** — exam uses Learn's alphabet/greetings chapters | M1 canonical syllabus layer + assets |
| G3 | Student selects exact exam scope (select all/section/individual, editable later) | Nothing | M2 scope selection + persistence |
| G4 | Exam profile (readiness target, available time, preferences) | Nothing | M3 |
| G5 | Adaptive diagnostic (5–10 min) | Learn Mode has `diagnostic_engine.dart` + screen — **for Learn languages, not CBSE exam tracks**; reusable pattern, not reusable content | M4 (extend spine pattern) |
| G6 | AI planner (Gemini) with validation/fallback/cache/rate-limit | Gemini adapter + OfflineTutor exist for **chat** only; no planner function | M5 (reuse adapter infra) |
| G7 | Learning + practice loop scoped to syllabus items | Learn sessions exist for Learn curriculum; exam practice not scope-aware | M6 |
| G8 | Answer evaluation (typed + photo, rubric-based) | MCQ-only instant feedback. No typed/photo answers, no rubrics | M7 (photo pipeline, image input) |
| G9 | Weak-area system + forgetting-aware revision | Learn spine has `mastery_scheduling.dart` (revision scheduling!) + `adaptive.dart` next-action; not wired to exam tracks | M8 (extend, do not duplicate) |
| G10 | PYQs + mini/full mocks | Nothing | M9 |
| G11 | Exam home ("what do I do today") | Home screen routes to existing exam screen only | M10 |
| G12 | Content layers (official/trusted/AI-generated labels) | No layering anywhere | M5–M9 progressive |

**Reuse decision (G5/G9 are the big ones):** the Learn-2.0 spine (`learner_profile`, `learning_state`, `mastery`, `mastery_scheduling`, `diagnostic_engine`, `planner`) is architecturally aligned with the Exam 2.0 vision but its domain types are Learn-language-specific (goal/level/practice-style per language). The Exam Mode needs its own exam-profile domain but should **reuse the mastery-scheduling and diagnostic-engine patterns and the Gemini adapter infrastructure verbatim**. Duplicating the AI adapter or the progress persistence would violate the master plan's "extend, don't duplicate" rule.

---

## 4. Syllabus PDFs — Source-of-Truth Findings (input to M1)

Full extraction details live in `docs/Syllabus/INGESTION_REPORT.md` (M1). Headline findings the audit must flag:

1. **All six PDFs have damaged embedded text layers for Devanagari** (custom font encodings without usable ToUnicode maps for conjuncts). Raw text extraction is unreliable for content strings. **Mitigation used:** structure/marks parsed from text layer + every content string verified by OCR of 300+ DPI page renders. Items that could not be verified with high confidence are flagged `ocrUncertain` in the canonical data — never silently guessed.
2. **Class 9 literature chapters are NOT published yet in any of the Class 9 PDFs.**
   - Class 9 Sanskrit: prescribed textbook & chapters = *“शीघ्रमेव सूचयिष्यते”* (will be announced shortly) — the PDF says the full syllabus with textbook chapters will follow.
   - Class 9 Hindi (आर-1/आर-2): पाठ्यपुस्तक section says study per the NCERT textbook issued under राष्ट्रीय पाठ्यचया रूपरेखा 2023 — **no book titles, no chapter lists**.
   - **Consequence:** Class 9 tracks ingest section structure + grammar + writing with full fidelity, and carry an explicit `pendingOfficialAnnouncement` flag on literature. The app must render these as “awaiting official chapter list” and NEVER invent chapters. (This is exactly the NCF-SE 2023 transition the user warned about: “CBSE has changed parts of the Class IX language structure for 2026–27”.)
3. **Class 9 Hindi PDF contains TWO courses** (आर-1 first-language track and आर-2 second-language track) with different grammar/writing specs → ingested as two course entries (6 PDFs → 7 canonical course files; the V1 “six tracks” remain as specified, Class 9 Hindi simply has two course variants).
4. **Class 10 Sanskrit (122) chapter table lists 9 chapters numbered 1–8 and 10 — नवम (9) is absent in the official table itself.** Recorded verbatim + flagged; chapter 9 is NOT invented.
5. Class 10 Hindi A/B and Sanskrit Communicative (119) chapter lists are complete and verified (Communicative ch. 10 & 11 are marked “internal assessment only” in the PDF itself).
6. Internal assessment (20 marks) structure is specified in all six PDFs and is preserved in the canonical data (classified as internal, not board-exam scope, per master plan §7).

---

## 5. Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| Inventing Class 9 literature chapters because “empty” feels broken | **CRITICAL** | Canonical schema supports `pendingOfficialAnnouncement`; UI contract: show pending state, disable literature scope selection for those courses until data lands (M2) |
| Devanagari encoding corruption in future PDFs | High | Ingestion pipeline (scripts/syllabus) does text-layer + OCR dual-verification; `ocrUncertain` flags surfaced in ingestion report for human review |
| Breaking Learn Mode while building Exam Mode | High | M1 adds new assets + new exam domain files only; zero edits to Learn code paths; Learn regression tests remain green |
| Devanagari rendering in exam UI | Medium | Already solved: `AppTextStyles.sanskritBody` + Poppins pipeline is proven in Learn screens; JSON assets with Devanagari are proven (`assets/curriculum/learn/*.json` ship Devanagari content correctly) |
| Hard-coding CBSE into the engine | Medium | M1 models syllabus as `board → track → course` with a `BoardId` value type and board-agnostic loaders; CBSE is data, not code |
| AI hallucination over syllabus | High (later milestones) | M1 gives every syllabus item a stable ID; planner prompts (M5) will be constrained to these IDs; validation layer rejects out-of-scope output |
| Existing users' XP/streak/attempts | Medium | M1 touches no progress code; migration concerns handled in M3 when exam profile lands |
| Supabase/Gemini keys in repo | Low | Verified: keys live in `assets/env/.env` (git-ignored) + `.env.example` template; no secrets committed. M1 adds no secrets |

---

## 6. Milestone Execution Plan (confirmed, milestone-by-milestone)

- **M1 (this drop):** canonical syllabus ingestion — `assets/syllabus/cbse/*` (7 course files + index), Dart domain models + board-agnostic loader under `lib/features/exam/data/syllabus/`, ingestion report + source mapping, validation test suite. No UI change; existing exam mode untouched and still passing.
- **M2:** syllabus selection UI (board→class→subject→course, select all/section/individual, persist scope, edit later).
- **M3:** exam profile (readiness target, available time, preferences, persistence + migration safety).
- **M4:** adaptive diagnostic engine for exam tracks.
- **M5:** Gemini planner layer (validation, fallback, cache, rate-limit, replanning).
- **M6–M9:** learning/practice loop, answer evaluation (typed+photo), weak areas+revision, PYQs+mocks.
- **M10–M12:** home integration, VAN context, gamification wiring, student simulations, final QA freeze.

Each milestone ships a complete replacement-ready ZIP + test run, per the master plan.

---

## 7. Test Inventory (existing, must stay green)

108 test files across `test/features/{achievements,ai,environment,exam,home,learn,onboarding,profile,progress,settings,van}`, `test/accessibility`, `test/app`, `test/core`, `test/platform`. Exam-relevant existing tests that gate every future change: `exam_content_grounding_test.dart`, `quiz_bank_single_source_test.dart`, `quiz_notifier_test.dart`, `exam_selection_test.dart`, `exam_flow_widget_test.dart`, `exam_option_semantics_test.dart`, `quiz_attempts_cap_test.dart`.

M1 adds: `test/features/exam/syllabus/*` (schema validation, mark totals, ID uniqueness/stability, course isolation, pending-announcement flags, board-agnostic loader tests).
