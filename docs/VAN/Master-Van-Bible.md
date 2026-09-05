# VAN Master Bible

The single entry point for everything about **Van**, the emotionally
intelligent duck companion at the heart of VaaniX. This bible indexes the
eight design chapters and the implementation contract, and states the
current production status honestly — including what is still waiting on
external art.

> **One-paragraph identity.** Van is not a mascot; he is the learner's
> companion. He reacts to what the learner actually does (lessons, quizzes,
> streaks, AI conversations), never to fake events. He is warm, encouraging
> and honest — he celebrates real wins, shows gentle concern on real
> setbacks, and never manipulates. His voice is short, kind and specific.

## Part I — Design chapters (docs/VAN/)

| Chapter | File | Scope |
| --- | --- | --- |
| 1. Character Identity | `01 - Character Identity.md` | Who Van is; emotional role; boundaries. |
| 2. Visual Design | `02 - Visual Design.md` | Silhouette, proportions, palette, fallback rendering language. |
| 3. Expressions | `03 - Expressions.md` | The expression set and what each means. |
| 4. Animations | `04 - Animations.md` | Motion principles; per-state animation intent; Lottie/Rive targets. |
| 5. Outfits | `05 - Outfits.md` | Cosmetic unlocks; identity-preserving constraints. |
| 6. Personality Modes | `06 - Personality Modes.md` | Cheerleader / calm / thoughtful modes; user control (including reset). |
| 7. Voice & Communication | `07 - Voice & Communication.md` | Speech-bubble copy rules: short, kind, specific, never sarcastic. |
| 8. World & Interaction | `08 - World & Interaction.md` | The nest (Home), tap interactions, presence across screens. |

The chapters are the source of truth for *intent*. Where implementation
differs (fallback rendering instead of final art), the difference is
recorded below, not silently absorbed.

## Part II — Implemented system (as of Phase 6)

Technical contract: `docs/VAN/Implementation.md`. Summary:

- **Event-driven**: feature controllers dispatch `VanEvent`s; `VanController`
  resolves a `VanReaction`, arbitrates priority and exposes
  `VanPresentationState` via Riverpod; `VanWidget` renders.
- **States**: `idle, happy, thinking, focus, caring, surprised, sad, funny,
  achievement, speaking, error` — each with stable id, priority, duration,
  interruptibility and fallback (table in Implementation.md).
- **All designed events are live** (wired in Phase 3): `lessonStarted`,
  `lessonCompleted`, `quizStarted`, `quizAnswerCorrect/Wrong`,
  `perfectScore`, `quizCompleted`, `achievementUnlocked`,
  `streakExtended` (genuine extension only), `onboardingCompleted`
  (nest reveal), `aiResponseFinished` (with a word-count-aware reading
  window), `appOpened`, `companionTapped`. `userIdle` is deliberately
  reserved — no genuine idle detector exists yet, and Van never reacts to
  invented events.
- **Cooldowns**: system-initiated reactions (`appOpened`,
  `streakExtended`, `onboardingCompleted`) are gated by
  `vanIdleCooldownMs` (30 s default, injectable clock). Task feedback,
  milestones, taps and AI lifecycle are never gated — a learner's earned
  reaction must always arrive.
- **Burst consolidation**: multi-achievement loops collapse into a single
  reaction + one "+N more" snackbar.
- **Catalog**: `assets/van/metadata/van_assets.json` is the authoritative
  visual catalog, loaded through `van_asset_catalog_loader.dart` with a
  pinned JSON↔Dart parity test. All 11 final-art entries remain
  `pending_art`; the vector fallback is the production renderer until art
  ships.
- **Offscreen discipline**: the motion ticker pauses under disabled
  `TickerMode` and on paused/hidden lifecycle, and resumes cleanly.
- **SpeechStrip**: lives at its designed exam-preparation surface.
- **Personality reset**: Profile → "Reset to default" genuinely restores
  the default personality (Phase 5), matching Chapter 6's user-control rule.

## Part III — Open items (external)

| Item | Status | Unblock |
| --- | --- | --- |
| Final Lottie/Rive art (11 states) | `pending_art`; vector fallback in production | External art delivery, then catalog entries flip from `pending_art` |
| `userIdle` event | Reserved by design | Only implement with a genuine idle detector; otherwise keep removed |

Nothing in this bible overrides the curriculum content freeze or the
no-fake-events rule: Van reacts to real learner activity, full stop.
