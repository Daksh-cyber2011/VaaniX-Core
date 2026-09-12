# Learn 2.0 — M5: Dynamic Learning Content

Milestone 5 turns the content layer of Learn Mode dynamic without
touching a single piece of trusted content. Master Brief §15 asked for
exactly this shape:

> Do NOT throw away existing static curricula. Instead classify them as
> TRUSTED SEEDED CONTENT. They become available to the AI planner. The
> AI can select existing lesson / existing concept / existing exercise —
> or, where safe and supported, generate a personalized
> explanation/example/exercise. The system should prefer trusted content
> when available. AI-generated material must pass validation.

## What shipped

### 1. Trusted seeded content (§15/§32/§34) — `spine/content_registry.dart`

The A–G curricula are now CLASSIFIED, not replaced. For every concept in
the M1 graph the registry exposes:

- a **lesson entry** (`tc:<lang>:lesson:<lessonId>`) anchored to the same
  lesson id the graph uses — resolution is drift-free by construction;
- **exercise entries** (`tc:<lang>:ex:<exerciseId>`) from the existing
  language banks, with their type and bank order;
- a **`TrustedKnowledgeExcerpt`**: trusted vocabulary (exercise-answer
  words lead), trusted example sentences, and the lesson reference text —
  extracted VERBATIM from the shipped data.

The excerpt is the §16 "trusted knowledge layer": the AI may personalize
FROM it, never beyond it. Stub material yields an empty excerpt, and an
empty excerpt grounds NOTHING — the honest fail-closed default.

### 2. Generated material + the validation gate —
`spine/generated_content.dart`

`GeneratedContent` models the three §15 personalization kinds
(explanation / example / practice). Practice material is a REAL
trusted-shape `Exercise` whose anchors and id are FORCED — the model
cannot point it at another lesson or collide with a trusted id — so M6's
exercise engine can adopt it unchanged.

`GeneratedContentValidator` enforces:

| Brief | Rule implemented |
|-------|------------------|
| §45 | language gate, difficulty 1..5, structure, required fields, supported exercise type, expected answer present, explanation required |
| §45 | grounding: output must share vocabulary with the trusted excerpt ("where possible compare against trusted vocabulary/grammar data") |
| §46 | malformed material is DISCARDED (typed rejections), never fixed, never thrown; caller falls back to trusted content |
| §47 | wrong-script target text (e.g. Latin text offered as Hindi) is rejected |
| §48 | script-direction metadata (Urdu RTL) carried through to rendering |

Generatable exercise types are deliberately narrowed to mcq / fillBlank /
translation — the set the inline runner can render safely ("where safe
and supported").

### 3. Prompts + parser — `spine/content_prompt.dart`,
`spine/generated_content_parser.dart`

The §62 prompt discipline (SYSTEM / LANGUAGE KNOWLEDGE / LEARNER STATE /
TASK) with §16 grounding rules and an honest escape hatch: a model that
cannot stay grounded returns `{"kind":"none"}` and the caller falls back
to trusted content instead of fabricating. The parser reuses the M4
fence/prose-tolerant JSON extractor; everything runs through the
validator before any caller sees it.

### 4. Caching + the generator —
`data/generated_content_repository.dart`,
`data/personalized_content_generator.dart`

Generated material is cached under `learn_profile_<iso>_gen` (inside the
M2 namespace, so the prefix-scoped reset covers it), bounded to 12
newest-first entries with the 7-day freshness policy — §35 caching and
§61 cost control in one place. The generator walks the §34 ladder for
one concept:

```
cached personalization (0 network, re-validated)
  → ONE grounded Gemini call → validated → write-through cache
  → typed Left (trusted content stays on screen)
```

It reuses the M4 `PlannerTextClient`, so planner + material maker share
ONE app-wide 15 RPM Gemini budget (§36). An empty excerpt refuses before
any network call.

### 5. Smart Practice screen — `screens/smart_practice_screen.dart`

`/learn/smart` (entry card on the Learn screen, auth-gated with the other
Learn routes):

- **Focus** — today's validated plan step with an honest source label
  (AI-planned / Saved plan / Daily mix, §63).
- **Trusted material** — the concept's lesson card + exercise-bank
  summary, deep-linking into the EXISTING lesson and practice flows.
  Trusted content is the default view and never disappears (§34).
- **Make it personal** — three learner-triggered chips (Explain
  differently / Show examples / Quick quiz). Results render inline with
  "Made for you · AI" labelling; Urdu target text renders RTL (§48).
- The generated practice runner is a PREVIEW: it never writes progress,
  XP or mastery — the trusted practice flow remains the only scorer
  (M6 integrates generated material properly).
- Offline / decline / garbage → the trusted view stays and a friendly,
  honest note appears (§46: never broken exercise UI, no dead ends).

Provider wiring lives in `learn_content_providers.dart`
(`trustedContentRegistryProvider`, `generatedContentRepositoryProvider`,
`personalizedContentGeneratorProvider`, `smartPracticeProvider`).
`LearningPlanLike` gained ADDITIVE per-activity parallel lists
(concept anchors, kinds, reasons, difficulties) so content resolution
can ground plan steps without widening the plan contract.

## Deliberate M5 boundaries

- **Trusted-first, always.** `prepare()` makes ZERO AI calls; AI is
  only the learner-triggered personalization layer on top of trusted
  material (§34 priority ladder).
- **No XP from AI material.** Generated practice is explicitly a
  preview; the trusted flow keeps its role as the only scorer.
- **No generation for stub concepts.** An empty excerpt grounds nothing;
  the generator refuses before spending a token.
- **Generatable set stays narrow.** mcq / fillBlank / translation only;
  ordering and matching stay trusted-only until the engine work in M6.

## Tests

Six new files (static-validated; `flutter test` on a machine with the
SDK remains the executable gate):

- `trusted_content_registry_test.dart` — registry on the real Hindi
  curriculum + bank (lesson entries, exercise entries, excerpt
  vocabulary drawn from trusted text, stub honesty).
- `generated_content_validation_test.dart` — the §45/§46/§47/§48 matrix:
  every rejection reason, wrong-script rejections, grounding pass/fail,
  anchor forcing, JSON round-trip.
- `content_prompt_test.dart` — prompt sections, schema honesty
  (generatable types only, none-escape), excerpt content, RTL wording.
- `generated_content_repository_test.dart` — round-trip, bounded size,
  freshness, corruption safety, wrong-language rejection, prefix reset.
- `personalized_content_flow_test.dart` — cache→AI→write-through with a
  counting fake client, offline Lefts, decline handling, garbage →
  trusted fallback, re-validation of stored material.
- `smart_practice_screen_test.dart` — the widget flow over real content:
  trusted cards, honest labels, the personalization path with a fake
  client, and the offline note.

## Validation + packaging

`scripts/m5_validate.py` (balance, import resolution, symbols, 10-asset
sanity, byte diff vs the M4 ZIP with an explicit allow-list) must pass
before packaging; `scripts/m5_package.py` produces the complete-project
ZIP and the Python-rejoiner split (JOIN_ME.py — no .bat).
