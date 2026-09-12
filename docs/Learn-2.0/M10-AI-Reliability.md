# M10 — AI Reliability

**Status:** COMPLETE · **Milestone:** 10 of 12 · **Date:** 2026-09-11

## What this milestone is

Adversarial hardening of every AI entry point (Master Brief §90). The
planner and the content generator were already failure-first by design
(M4/M5: typed Lefts, never throws); M10 runs the brief's FULL
adversarial matrix against them, closes the two gaps the audit found,
and pins the whole matrix in tests so it can never silently regress.

## The §90 matrix — all twelve cases covered

| # | Attack | Outcome |
|---|--------|---------|
| 1 | empty AI response | typed Left (AiContentFilter path) |
| 2 | wrong language | wrongScript rejection; cross-language cache refused |
| 3 | hallucinated concept | unknown conceptId → Left (never grounded) |
| 4 | invalid exercise | unsupported type / bad index → rejected |
| 5 | malformed JSON | extraction null → Left |
| 6 | missing field | missingFields rejection |
| 7 | very long response | **NEW: bounded before scan** + size caps |
| 8 | unexpected Unicode | **NEW: control/bidi rejection** (ZWNJ/ZWJ allowed) |
| 9 | API timeout | TimeoutException → TimeoutFailure |
| 10 | rate limit | quota error → typed Left; shared 15 RPM budget intact |
| 11 | network unavailable | Left BEFORE any network call |
| 12 | cached stale plan | freshness contract refuses; chain continues |

Plus the recovery proof (§36): after EVERY failure above, the
deterministic planner still serves a usable plan and an honest decline
falls back to trusted content — Learn Mode never becomes unusable
because an AI call failed.

## Gaps found by the audit and closed

1. **Very long responses** (`planner_prompt.dart`): `extractPlanJson`
   now bounds any reply over 256 KB BEFORE the balanced-brace scan —
   a pathological reply can no longer cost unbounded work.
2. **Unexpected Unicode** (`generated_content.dart`): the validator
   rejects control characters, bidi overrides (U+202A–202E), bidi
   isolates (U+2066–2069), the BOM and zero-width spaces across every
   text field (title, body, example lines, exercise prompt/options/
   answers/explanation). ZWNJ (U+200C) and ZWJ (U+200D) are
   deliberately ALLOWED — they are required Indic orthography (the
   shipped Tamil/Telugu lessons use ZWNJ), and carry no spoofing risk.

## Verified honestly

`test/features/learn/ai_reliability_test.dart` drives every case
through the real fakes boundary (no network, no key needed). All
existing M4/M5 planner and content tests still pass unchanged — the
hardening is strictly additive to their contracts.
