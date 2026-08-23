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
Flutter `CustomPainter` renderer with a soft-vector duck silhouette, warm yellow
feathers, signature three-feather tuft, rounded orange beak and feet, blue hoodie
with drawstrings/mark, cream belly, and state-specific eyes, wing gestures and
beak poses. It uses no generic icons or emoji. This avoids an asset load failure+
and is Android/iOS safe while retaining an approved-art replacement boundary.

The fallback motion is deterministic and phase-based: idle uses breathing,
gentle vertical movement, eye tracking and two brief blinks; thinking/focus,
caring/sad, funny, speaking, achievement, surprised, and error each have a
distinct pose or controlled motion. Achievement/surprise alone use restrained
painted sparkles. When `MediaQuery.disableAnimations` is enabled, VAN keeps its
state-specific posture but removes bobbing, scale changes, blinking, speaking
pulses and animated wing/sparkle effects. The painter sits in a repaint boundary,
and its ticker naturally pauses under Flutter's `TickerMode` when inactive.

Speech bubbles constrain themselves to the available viewport, wrap at user text
scaling, include a small visual tail, and announce loading text as a live region.

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
fallback, every supported fallback state, reduced-motion asset bypass, and a
narrow text-scaled speech bubble. Tests do not require final art.
