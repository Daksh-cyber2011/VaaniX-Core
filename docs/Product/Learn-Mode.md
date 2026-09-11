# Learn Mode

VaaniX Learn Mode is a structured language-learning product, distinct from
Exam Mode (which is board/syllabus-oriented). The two must never be merged:
Learn Mode courses are NOT translations of Exam Mode Sanskrit content, and
Exam Mode content is NOT a substitute for Learn Mode curricula.

## Two-track architecture (Part 0 Foundation)

```
                                   ┌─────────────────────────────────┐
                                   │ assets/curriculum/v1.json       │
                                   │ (Sanskrit Exam Mode curriculum) │
                                   └─────────────────────────────────┘
                                                ▲
                                                │
                              loadCurriculum()  │  loadAllQuizQuestions()
                                                │
                                  ┌─────────────┴──────────────┐
                                  │ curriculumProvider         │  ← Exam Mode
                                  │ (AsyncNotifierProvider)    │     (legacy)
                                  └────────────────────────────┘

                                   ┌─────────────────────────────────┐
                                   │ assets/curriculum/learn/       │
                                   │   hi.json  bn.json  mr.json   │
                                   │   te.json  ta.json  gu.json   │
                                   │   ur.json  kn.json  ml.json   │
                                   │   or.json                     │
                                   │ (10 per-language Learn curricula)│
                                   └─────────────────────────────────┘
                                                ▲
                                                │
                                loadLearnCurriculum(LearnLanguage)
                                                │
                                  ┌─────────────┴──────────────┐
                                  │ learnCurriculumProvider     │  ← Learn Mode
                                  │ (AsyncNotifierProvider      │     (Part 0+)
                                  │  .family<LearnLanguage>)    │
                                  └────────────────────────────┘
                                                ▲
                                                │
                                  selectedLearnLanguageProvider
                                                │
                                  ┌─────────────┴──────────────┐
                                  │ LearnLanguageSelectionScreen│
                                  │ (/learn/language)           │
                                  └────────────────────────────┘
```

The two provider trees are deliberately separate. Selecting Hindi in the
picker never loads Bengali; selecting any Learn language never pollutes
the Sanskrit Exam Mode tree. The Sanskrit path remains the default when
no Learn language has been chosen, so the existing Learn screen keeps
working during the Part 0 → Part A transition.

## The 10 Learn Mode languages (LOCKED)

| # | Language   | Code | Native name | Script        | Direction |
|---|------------|------|-------------|---------------|-----------|
| 1 | Hindi      | hi   | हिन्दी      | Devanagari    | LTR       |
| 2 | Bengali    | bn   | বাংলা       | Bengali       | LTR       |
| 3 | Marathi    | mr   | मराठी       | Devanagari    | LTR       |
| 4 | Telugu     | te   | తెలుగు      | Telugu        | LTR       |
| 5 | Tamil      | ta   | தமிழ்       | Tamil         | LTR       |
| 6 | Gujarati   | gu   | ગુજરાતી    | Gujarati      | LTR       |
| 7 | Urdu       | ur   | اُردُو      | Nastaliq      | **RTL**   |
| 8 | Kannada    | kn   | ಕನ್ನಡ       | Kannada       | LTR       |
| 9 | Malayalam  | ml   | മലയാളം     | Malayalam     | LTR       |
| 10| Odia       | or   | ଓଡ଼ିଆ       | Odia          | LTR       |

This list is locked by the VaaniX Learn Mode Master Execution brief. Do
not add, remove, or reorder without an explicit Part directive.

## Pedagogical standard

Each language should follow a meaningful progression (adapted per language,
not forced into a single template):

- **Level 0** — Script / Foundation / Survival
- **Level 1** — Beginner
- **Level 2** — Elementary
- **Level 3** — Lower Intermediate
- **Level 4** — Intermediate

Completing Level 4 does NOT mean advanced fluency. The architecture stays
extensible for future advanced levels.

## Per-language curriculum contract

Each language's curriculum is a standalone JSON file at
`assets/curriculum/learn/<code>.json`. The schema (version 1):

```jsonc
{
  "schemaVersion": 1,            // must match kLearnCurriculumSchemaVersion
  "language": {
    "enum": "hindi",             // LearnLanguage enum name
    "iso639_1": "hi",
    "englishName": "Hindi",
    "nativeName": "हिन्दी",
    "scriptName": "Devanagari",
    "scriptCode": "Deva",        // ISO 15924
    "direction": "ltr"           // "rtl" only for Urdu
  },
  "levels":     [],              // future: Level 0..4 scaffolding
  "chapters":   [],              // Chapter[] — see progress_models.dart
  "quizzes":    [],              // quiz groups, see progress_models.dart
  "vocabulary": []               // future: per-language vocabulary index
}
```

The loader (`loadLearnCurriculum` in `curriculum_loader.dart`):
- reads the asset,
- validates `schemaVersion` (refuses to load a newer schema than the
  constant, returns empty — never throws),
- parses `chapters` into the existing `Chapter` / `Lesson` domain models
  (shared with Exam Mode),
- returns `[]` for any failure (asset missing, JSON malformed, schema
  mismatch) so the picker stays alive.

## Per-Part delivery plan

| Part | Scope                                                 | Asset replaced           |
|------|-------------------------------------------------------|--------------------------|
| 0    | Catalogue + picker + dispatch + stubs (THIS PART)     | (all 10 stubs added)     |
| A    | Hindi curriculum                                      | `hi.json`                |
| B    | Bengali curriculum                                    | `bn.json`                |
| C    | Marathi curriculum                                    | `mr.json`                |
| D    | Telugu curriculum                                     | `te.json`                |
| E    | Tamil curriculum                                      | `ta.json`                |
| F    | Gujarati curriculum                                   | `gu.json`                |
| G    | Urdu curriculum (special care: Nastaliq + register)   | `ur.json`                |
| H    | Kannada curriculum                                    | `kn.json`                |
| I    | Malayalam curriculum                                  | `ml.json`                |
| J    | Odia curriculum                                       | `or.json`                |
| K    | Cross-language integration + regression               | (no asset changes)       |
| L    | Final QA + freeze                                     | (no asset changes)       |

## Lesson flow (unchanged from V1)

**READ -> LEARN -> PRACTICE -> FEEDBACK -> MASTER -> COMPLETE**

1. **Read** — lesson content screen renders the markdown-like lesson
   (headings, tables, tips) with script-aware typography (Devanagari,
   Bengali, Tamil, etc.).
2. **Learn** — the content itself: script foundation, vocabulary in
   context, sentence patterns, grammar, conversation, reading.
3. **Practice** — `ExerciseScreen` runs the exercise engine: MCQ,
   fill-in-the-blank, ordering, translation, matching.
4. **Master** — scoring counts each exercise once (first correct answer);
   retry improves understanding without inflating the score. Spaced
   review returns weak items more frequently.
5. **Complete** — finishing a session marks the lesson complete via the
   idempotent progress path (XP awarded exactly once), fires VAN events
   and unlocks achievements through the same checker as the lesson screen.

Engines are content-driven: a new curriculum drops into
`assets/curriculum/learn/<code>.json` without UI changes.

## What's NOT in Part 0

- No actual language curricula. All 10 stubs return empty chapter lists.
- No per-language XP isolation (XP is still global).
- No per-language mastery store (mastery is still keyed by lessonId
  across all languages — fine while lessonIds stay globally unique, which
  the per-language asset convention guarantees by prefixing with the
  language code, e.g. `hi_ls_alphabet_vowels`).
- No localization of the app UI into the 10 languages (the picker renders
  native names, but app chrome stays English).
- No audio. Curriculum content is audio-ready (lesson content is plain
  text the future TTS layer can read), but no audio assets ship.

These are deliberate Part 0 boundaries. They lift in later Parts as each
language's curriculum lands and as the product evolves.
