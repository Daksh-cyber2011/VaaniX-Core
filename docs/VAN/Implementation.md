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

| State | V1 fallback presentation | Final asset | Duration / fallback |
| --- | --- | --- | --- |
| idle | breathing and gentle bob | `duck_idle_loop` | loop |
| happy | warm open expression | `duck_happy_short` | 1.4s → idle |
| thinking | head tilt / considering | `duck_thinking_loop` | sustained |
| focus | still, attentive posture | `duck_focus_loop` | sustained |
| caring | gentle inclined posture | `duck_caring_short` | 2.4s → idle |
| surprised | expanded pose | `duck_surprised_short` | 1.8s → idle |
| sad | mild concern only | `duck_sad_soft` | 1.8s → idle |
| funny | playful tilt | `duck_funny_short` | 1.2s → idle |
| achievement | animated celebratory scale/bob | `duck_achievement_celebrate` | 2.6s → idle |
| speaking | response presentation | `duck_speaking_loop` | 2.2s → idle |
| error | brief recoverable wobble | `duck_error_soft` | 2.6s → idle |

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

## Canonical static expression artwork (integrated 2026-09)

The canonical VAN expression set supplied by the artist is now the production
static visual. Eight expression PNGs live under `assets/van/expressions/`
(transparent background preserved, displayed exactly as supplied — only the
original file names were normalised to semantic names; provenance is recorded
in `van_assets.json`):

| Canonical expression | File | Reached from states |
| --- | --- | --- |
| neutral | `neutral.png` | idle |
| thinking | `thinking.png` | thinking, focus |
| happy | `happy.png` | happy, funny |
| excited | `excited.png` | surprised |
| motivating | `motivating.png` | caring, speaking |
| confused | `confused.png` | error |
| sleepy | `sleepy.png` | sad (supplied art covers tired-or-sad) |
| achievement | `achievement.png` | achievement |

No new `VanState` was created: the state vocabulary, priorities, and
interruptibility are untouched. `VanStateExpressionX.canonicalExpression`
(`van_expression.dart`) is the deterministic state → expression mapping.
`VanAssetCatalog.expressionFor` / `expressionForState` / `staticArtForState`
provide stable semantic access; UI code never hardcodes asset paths.

Rendering precedence in `VanVisualRenderer` / `VanWidget`:

1. available Lottie animation asset (future canonical animations) — wins;
2. canonical static expression artwork — no motion transforms may reshape
   canonical art, and a static image is inherently reduced-motion safe;
3. the Flutter fallback painter with its full motion system.

The artwork is contain-fit inside the widget stage: original proportions,
crop-free, transparency preserved. A missing or unreadable canonical file
falls back safely to the Flutter painter (no crash, no broken image, no
silent expression substitution — the fallback always reflects the current
state's pose).

Accessibility: the widget's semantics label names the visible expression
(`"Van — thinking"`, `"Van — excited"`, …) so expression changes are never
communicated by artwork alone. The label is static (no live region), so no
per-frame announcements occur. `widget.semanticLabel` still overrides.

`assets/van/master/VAN_master.png` is reference material for the art
pipeline and is deliberately not declared in pubspec (nothing reads it at
runtime).

## Animation and assets (animation layer — pending)

The canonical static expression artwork (above) is the production visual; the
following Flutter `CustomPainter` character remains the deterministic fallback
whenever canonical art is unavailable (art-free hosts, load failure, art-free
catalog injection) — a soft-vector duck silhouette, warm yellow
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
all animation entries remain deliberately marked unavailable until approved
source animation art is added (schemaVersion 3 now also pins the canonical
expression set). `duck` remains the permanent internal asset prefix; Van
remains the public default name.

`VanVisualRenderer` is the production default: it renders a catalog asset only
when it is explicitly marked available; missing, malformed, or unavailable
Lottie assets always fall back safely to the Flutter character (with the
canonical static expression artwork as the intermediate layer — see above).
The V1 asset manifest gives every required animation an ID, format, path,
duration, loop, fallback, V1 requirement, and status. The animation layer
remains pending until approved vector source files are supplied.


## Testing

`test/features/van/van_controller_test.dart` covers initial state, event
resolution, AI/Learn/Exam mappings, priority, critical interruption, timed
fallback, every supported fallback state, reduced-motion asset bypass, and a
narrow text-scaled speech bubble.

`test/features/van/van_expression_art_test.dart` covers the canonical art
layer: expression resolution, the full state → expression mapping, event →
state → art for every wired production event, art rendering in place of the
fallback painter (including under reduced motion), safe fallback for a
missing asset file, and the expression semantics label.

`test/features/van/van_asset_catalog_parity_test.dart` additionally pins the
JSON `expressions` section to `kVanCanonicalExpressionArt` (1:1, no
drift, every file present on disk) alongside the animation-layer parity.
