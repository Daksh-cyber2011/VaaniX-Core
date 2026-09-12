# M9 — All Ten Languages

**Status:** COMPLETE · **Milestone:** 9 of 12 · **Date:** 2026-09-11

## What this milestone is

The adaptive engine is stable — so the knowledge fills in. M9 integrates
language knowledge for ALL TEN locked languages by completing the last
three: Kannada (Part H), Malayalam (Part I) and Odia (Part J), each with
a full five-chapter, twenty-lesson native-script curriculum and authored
practice exercises. The support matrix (Master Brief §74) now passes for
every language:

language profile · script · direction · knowledge data · content
mapping · exercise support · diagnostic support · planner support ·
mastery support · milestones.

No per-language engines exist and none were added — the shared spine
(`ConceptGraph`, `DiagnosticEngine`, `DeterministicPlanner`,
`AdaptiveSessionEngine`, mastery, milestones) consumes
language-specific DATA only. Adding a language means adding data files,
never code forks (§74: "must not require HindiLearningEngine …").

## What shipped per language (kn / ml / or)

- **Curriculum** (`assets/curriculum/learn/<code>.json`): 5 chapters ×
  4 lessons, schema-identical to Parts A–G:
  1. Script fundamentals (vowels, consonants, vowel signs, conjuncts —
     including Kannada ವಟ್ಟಕ್ಷರ, Malayalam ചില്ല്, Odia dotted ଡ଼/ଢ଼)
  2. Greetings & Introductions
  3. Daily Life (SOV sentences, questions, negation, routine)
  4. Grammar (pronouns, tenses, cases, politeness)
  5. Reading (conversations, paragraph, proverbs, review)
- **Native-script lesson content** written for the language — not
  flattened into English transliteration (§75), with natural examples,
  tables, and mini-practice closers.
- **Exercise banks** (`kannada_exercises.dart`,
  `malayalam_exercises.dart`, `odia_exercises.dart`): 3 grounded
  exercises per lesson (60 each), all five engine types, explanations
  that teach WHY.

## Integration changes (the only code touched)

- `exercise_providers.dart`: the three new banks join the fallback
  chain (additive; contract unchanged).
- `learn_screen.dart`: the "curriculum in development" banner is now
  DATA-DRIVEN — derived from the loaded curriculum instead of a
  hardcoded language list. Future languages need zero UI changes.

## Safety guarantees verified

- **§76 Urdu RTL**: Urdu remains the only RTL language; catalogue
  metadata unchanged; the Urdu curriculum and exercise bank untouched.
- **§77 Unicode safety**: every kn/ml/or lesson title and content is
  validated to touch its own ISO 15924 block (Knda / Mlym / Orya) and
  to contain NO characters from any other Indic/Arabic block — the
  mojibake guard is enforced at generation time AND in tests.
- **§84 Exam Mode protection**: no Learn asset uses the `ls_` Exam
  Mode prefix; all ten language banks are disjoint; the Sanskrit Exam
  Mode path is untouched.
- **Milestone compatibility**: the 5-chapter ladder means the M7
  ordinal milestone criteria resolve for all ten languages
  automatically.

## Test coverage

`test/features/learn/language_support_matrix_test.dart` walks the §74
checklist for all ten languages: catalogue integrity, RTL rules,
curriculum schema, per-lesson content depth, exercise coverage and
anchoring, script-block correctness, milestone derivability, Exam Mode
isolation and bank disjointness.
