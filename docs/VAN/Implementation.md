# VAN implementation

## Scope and architecture

VAN is an event-driven feature under `lib/features/van`. It owns no AI,
curriculum, routing, or persistence system. Existing feature controllers emit
`VanEvent`s; `VanController` resolves a `VanReaction`, arbitrates priority,
and exposes `VanPresentationState` through Riverpod. `VanWidget` renders the
result and keeps its original direct-state API for existing screens.

```
Learn / Exam / AI lifecycle -> VanEvent -> VanController -> VanPresentationState
                                                        -> VanWidget -> renderer
```

## States

The legacy compatible states are `idle`, `happy`, `thinking`, `focus`,
`caring`, `surprised`, `sad`, `funny`, and `achievement`. V1 additionally
uses `speaking` for a completed AI response presentation and `error` for a
recoverable system failure. Definitions in `van_state.dart` carry a stable id,
meaning, priority, default duration, interruptibility, fallback, and speech,
AI-thinking, and interaction permissions.

## Events and integration API

`VanEvent` has a typed id, optional short speech-bubble message, and structured
payload. Supported V1 events cover lesson, quiz, AI, achievement, onboarding,
idle/error, and companion-tap lifecycles. Call:

```dart
ref.read(vanControllerProvider.notifier).dispatch(
  const VanEvent(VanEventType.quizAnswerCorrect),
);
```

The Chat controller emits thinking, speaking, and gentle failure events. The
lesson screen emits start/completion and achievement events. The exam screen
emits quiz start, answer feedback, completion, and perfect-score events.

## Priority and interruption

Priority is `critical > achievement > feedback > interaction > task > idle`.
Lower-priority reactions never interrupt a current reaction. An uninterruptible
achievement can only be replaced by a critical error. Explicit lifecycle end
events (`aiResponseFinished`, `userIdle`) settle to idle. Finite reactions use
a cancel-safe timer and return to their declared fallback.

**[DECISION REQUIRED]** The Animation Bible lists `user interactions >
teaching > celebrations > idle`, while the product brief requires a major
celebration not to be interrupted by incidental motion. V1 treats celebrations
as non-interruptible and lets only critical errors supersede them. Product
owners should confirm whether an explicit user tap should ever cancel a major
celebration.

## Animation and assets

There are currently no shipped VAN art assets. V1 therefore uses a lightweight
Flutter renderer with breathing, pose tilt, accessibility-aware reduced motion,
the required feather tuft, hoodie, and semantic labeling. This avoids an asset
load failure and is Android/iOS safe.

`VanAssetCatalog` and `VanVisualBuilder` separate state from visual technology.
Final Lottie (or another renderer) can be injected per `VanWidget` and must
return the supplied Flutter fallback if loading fails. `assets/van/metadata/
van_assets.json` reserves stable `duck_*` IDs, format, dimensions, and paths;
all entries are deliberately marked unavailable until approved source art is
added. `duck` remains the permanent internal asset prefix; Van remains the
public default name.

## Testing

`test/features/van/van_controller_test.dart` covers initial state, event
resolution, AI/Learn/Exam mappings, priority, critical interruption, timed
fallback, and fallback widget rendering. Tests do not require final art.
