# VaaniX — VAN Visual Layer

Production visual representation for VAN, and an honest account of what
exists, what was fixed, and what still needs a device.

---

## 1. Canonical VAN visual specification

Taken from the supplied artwork and confirmed by inspecting the rendered
PNG (not assumed):

| Trait | Value |
|---|---|
| Body | Short, chubby, cream-white 3D duck |
| Eyes | Large, glossy, dark with bright highlights |
| Brows | Expressive, dark brown, clearly separated |
| Cheeks | Rosy, both sides |
| Head tuft | Three-feather crest |
| Goggles | Cyan, glowing rim, worn over the eyes |
| Headphones | Navy/cyan, over the ears |
| Hoodie | White body with blue shoulders/sleeves |
| Zipper | Cyan, centre |
| Chest detail | Blue "V" |
| Shorts | Blue with white trim |
| Feet | Orange, three-toed |

These are the approved reference images. They are displayed **as
supplied** — no recolouring, no restyling, no proportion changes.

---

## 2. Asset technology: bundled RGBA PNGs

**Chosen: the eight existing PNGs in `assets/van/expressions/`, rendered
through Flutter's own `Image.asset`.**

The project already depended on `lottie`, and `VanAssetCatalog` already
declared eleven `duck_*` Lottie slots. The tempting move was to author
Lottie files. That would be wrong here:

* No source animation art exists. `assets/van/animations/` holds only a
  `.gitkeep`.
* Hand-authored Lottie would mean **redrawing the character in a
  different tool**, producing a second, subtly different VAN — exactly
  the "five slightly different ducks" failure.
* The approved art is already high-quality 1024×1536 renders.

So the pipeline is: **bundled PNG → frame-normalised → `Image.asset`**.
Lottie remains a declared, *unavailable* seam for when real animation art
is commissioned. No new dependency was added.

### Verified asset facts

All eight files are genuine 8-bit RGBA with real transparency (PNG colour
type 6). Corners sample `(0,0,0,0)`. 33–52% of pixels are near-opaque
(the character); 45–65% are fully clear (background). The dark surround
visible in a naive image viewer is fully transparent, **not** a baked-in
background — so there is no black box over the Learn surface.

---

## 3. The two production defects fixed in this pass

### 3.1 VAN changed size between states

The artwork is cut out inconsistently:

* `excited.png` has its arms spread; `motivating.png` and `thinking.png`
  have them tucked in.
* `sleepy.png` was supplied on a **1199×1312** canvas where the other
  seven are **1024×1536**.

`BoxFit.contain` scales by *canvas* size, so the character itself changed
size. Measured on a 160 px stage:

| expression | char W | char H | W/stage | H/stage |
|---|---|---|---|---|
| achievement | 96.9px | 139.5px | 0.605 | 0.872 |
| confused | 86.8px | 150.5px | 0.542 | 0.941 |
| excited | 101.6px | 145.4px | **0.635** | 0.909 |
| happy | 98.2px | 148.1px | 0.614 | 0.926 |
| motivating | 83.6px | 148.2px | **0.523** | 0.926 |
| neutral | 92.0px | 148.5px | 0.575 | 0.928 |
| sleepy | 83.8px | 140.0px | 0.524 | 0.875 |
| thinking | 84.4px | 150.4px | 0.527 | **0.940** |

**Height spread 7.9%, width spread 21.4%.** `excited` VAN rendered 18 px
wider than `motivating` VAN on the same stage — a visible pop on every
state change.

**Fix:** each expression carries a measured `VanExpressionFrame` — the
tight non-transparent bounding box, expanded by a small margin. The
renderer crops to it before display. The crop is a *uniform* scale plus a
translation inside a `ClipRect`, so proportions are never altered; only
the dead transparent margin is trimmed.

| expression | char W | char H | H/stage |
|---|---|---|---|
| achievement | 109.8px | 158.1px | 0.988 |
| confused | 91.2px | 158.2px | 0.989 |
| excited | 110.5px | 158.2px | 0.989 |
| happy | 104.9px | 158.2px | 0.989 |
| motivating | 89.3px | 158.2px | 0.989 |
| neutral | 98.0px | 158.2px | 0.989 |
| sleepy | 94.4px | 157.8px | 0.986 |
| thinking | 88.8px | 158.2px | 0.989 |

**Height spread 7.9% → 0.3%.** Width still varies (24.5%) — correctly so,
because that is the artwork's pose: `excited` genuinely has its arms out.
Normalising height is the right axis for a standing character.

Frames are measured offline by `tools/png_character_extent.py` and
committed as data. Nothing is decoded at runtime, and **no PNG was
modified** — the supplied bytes are byte-for-byte unchanged.

### 3.2 VAN was completely static

The Animation Bible (`docs/VAN/04 - Animations.md`) opens with:

> Van should never feel static. Even when idle, Van should appear alive.

But canonical artwork rendered with `applyMotion = false` — zero motion.
The previous pass deliberately over-corrected, avoiding *all* transforms
to prevent reshaping the art. That conflated two different things:

* Non-uniform scale / rotation **would** distort the character.
* **Uniform** scale and translation **cannot** distort it.

**Fix:** canonical art now gets shape-preserving *stage* motion only — a
subtle uniform swell (0.4–1.2% amplitude, always ≥ 1.0) plus the
existing vertical drift. Per-part animation (wing flap, blink, beak,
pupil, tuft lift) remains exclusive to the painted fallback, which is the
only layer that can actually draw those parts.

---

## 4. Before → after architecture

The state machine was **not** touched. Before and after:

```text
App / AI / Learn events
        ↓
VanEvent  (unchanged)
        ↓
VanController / VanState  (unchanged — 11 states, priorities,
                            interruptibility, durations all identical)
        ↓
VanState.canonicalExpression   (unchanged mapping)
        ↓
VanVisualRenderer  ── CHANGED: crops to VanExpressionFrame
        ↓
Canonical PNG / Lottie seam / Flutter painter
        ↓
VanWidget  ── CHANGED: shape-preserving stage motion for canonical art
```

New data plumbing, no new state machine:

```text
van_expression.dart  ── VanExpressionFrame (new field on VanExpressionArt)
van_assets.json      ── per-expression "frame" (schemaVersion 3 → 4)
catalog_loader       ── parses "frame"; parity comparator includes it
```

---

## 5. State → visual mapping

The mapping is unchanged (`VanStateExpressionX.canonicalExpression`); only
the framing and motion are new.

| VanState | Expression | Asset | Stage motion |
|---|---|---|---|
| `idle` | neutral | `neutral.png` | breathing swell + drift |
| `happy` | happy | `happy.png` | small swell |
| `thinking` | thinking | `thinking.png` | very small swell (restrained) |
| `focus` | thinking | `thinking.png` | very small swell (restrained) |
| `caring` | motivating | `motivating.png` | small swell |
| `surprised` | excited | `excited.png` | small swell |
| `sad` | sleepy | `sleepy.png` | small swell (own canvas, normalised) |
| `funny` | happy | `happy.png` | small swell |
| `achievement` | achievement | `achievement.png` | larger swell (0→1.2%) |
| `speaking` | motivating | `motivating.png` | very small swell (0.5%) |
| `error` | confused | `confused.png` | very small swell |

All 8 expressions are reachable; none is dead artwork.

---

## 6. Fallback behaviour

Rendering precedence in `VanVisualRenderer`, unchanged in order:

1. An available Lottie animation asset — currently none are available.
2. Canonical expression artwork (frame-normalised).
3. The Flutter fallback painter.

`Image.asset` carries an `errorBuilder` that swaps in the Flutter painter,
so a missing or unreadable PNG yields the vector duck, never a broken
image and never a crash. `VanAssetCatalog.placeholder` (art-free) forces
layer 3 for tests and custom hosts. A malformed or missing
`van_assets.json` falls back to the Dart `VanAssetCatalog.v1` contract.

No per-frame logging. Fallback is structural, not a logged event.

---

## 7. Animation behaviour

| State | Motion |
|---|---|
| idle | 0.8% breathing swell + gentle vertical drift, 3.5 s cycle |
| speaking | 0.5% swell |
| thinking / focus / error | 0.4% swell |
| achievement | up to 1.2% swell |

Amplitude is highest at rest (where the Bible wants life) and minimal
during active states, so motion never competes with meaning. All values
are `≥ 1.0`, so the character can never appear to deflate or invert.

No seizure risk: the fastest component is a ~1.4 Hz cycle at ≤1.2%
amplitude. No per-frame logs. One `AnimationController`, disposed in
`dispose()`.

---

## 8. Accessibility / reduced motion

* `MediaQuery.disableAnimations` is honoured. Under reduced motion
  `stageScale` is exactly `1.0` and `verticalOffset` is `0.0`, so the
  canonical art is presented **completely still**. A static image is
  inherently reduced-motion safe.
* The painted fallback keeps its state-specific posture under reduced
  motion (wing angle, eye openness, pupil, beak) while losing all
  movement, so the expression stays readable.
* The ticker already stops under a disabled `TickerMode` or a
  backgrounded app (`van_widget_ticker_test.dart`).
* The widget's semantics label is `'Van — <expression>'`, so an
  expression change is announced by label and never by artwork alone. It
  is a static label, not a live region, so there are no per-frame
  announcements.

---

## 9. Performance

* **One** `AnimationController` per mounted `VanWidget`, disposed once.
* The fallback painter sits inside a `RepaintBoundary`, so motion does
  not repaint the surrounding subtree.
* The ticker stops when the subtree is offstage or the app is
  backgrounded — VAN does not animate invisibly.
* The canonical image uses `FilterQuality.medium` and
  `gaplessPlayback: true`, so expression changes never flash blank and
  the same decoded frame is reused.
* Flutter's own `ImageCache` handles decode reuse; no custom cache was
  added. Preloading would have meant a bespoke manager for eight images
  that are almost always already resident — not worth the complexity.

### Asset size — a real, unfixed issue

The eight PNGs total **~13.3 MB** and are bundled into the APK. That is
large for a mascot. Options exist (WebP, or 768×1152 re-export) but they
require **re-encoding the approved art**, which contradicts "displayed
exactly as supplied". I have therefore **not** touched them. See
§12 — this needs your decision.

---

## 10. Tests

| Suite | Count | Result |
|---|---|---|
| `test/features/van/van_visual_layer_test.dart` (**new**) | 20 | passed |
| `test/features/van/van_asset_catalog_parity_test.dart` (extended) | +2 | passed |
| `test/features/van/van_controller_test.dart` | existing | passed |
| `test/features/van/van_expression_art_test.dart` | existing | passed |
| `test/features/van/van_ai_bridge_test.dart` | existing | passed |
| `test/features/van/van_widget_capability_test.dart` | existing | passed |
| `test/features/van/van_widget_ticker_test.dart` | existing | passed |
| **Total `test/features/van/`** | **85** | **all passed** |

New tests pin: frame well-formedness, frames inside canvas, the
<2% height-consistency metric, `wholeImage` degradation, total
state→expression coverage, no dead artwork, sleepy's odd canvas, the crop
being present for framed art and absent for unframed art, safe fallback
for missing art, canonical art rendering for all 11 states, motion
presence, reduced-motion stillness, and ticker disposal.

### One existing test legitimately changed

`van_asset_catalog_parity_test.dart` asserted `schemaVersion == 3`. The
schema is now 4 because the `frame` object is load-bearing, not
cosmetic. The assertion was updated and the reason documented inline.
No other existing test needed changing — the state machine, mapping, and
fallback contracts are untouched.

---

## 11. Adding future VAN assets

1. Drop the PNG at `assets/van/expressions/<name>.png` (transparent).
2. Add the entry to `kVanCanonicalExpressionArt` **and** to
   `assets/van/metadata/van_assets.json` (schemaVersion 4).
3. Measure its character extent and record the frame:

   ```sh
   python tools/png_character_extent.py
   ```

   Copy the reported bbox, expanded by ~8 px so soft edges survive.
4. Run the parity tests — they will fail loudly on any drift between the
   JSON and the Dart contract, and if the height-consistency metric
   regresses past 2%.
5. If it is a *new* expression, add it to `VanExpression` and map at
   least one `VanState` to it (the "no dead artwork" test enforces this).

For genuine Lottie animation, drop a file at the declared
`duck_<state>_<name>.json` path and flip `available: true` in the JSON.
The renderer picks it up automatically and it takes precedence over the
static art — no code change needed. Do **not** hand-author Lottie: it
would be a different VAN.

---

## 12. Known limitations

1. **Device rendering was never verified.** No emulator or device was
   available. Every claim above about how VAN *looks* is derived from
   measured pixel geometry and code, not from a rendered screenshot.
2. **~13.3 MB of PNGs in the APK.** Needs your call — re-encoding
   conflicts with "display as supplied".
3. **Motion is stage-level only.** Wing flap, blink, beak and pupil
   animation exist solely in the painted fallback, because a static PNG
   cannot be rigged. Real per-part animation requires real animation
   assets.
4. **No per-expression pupil/eye direction.** Supplied art has fixed
   gazes. `thinking` looks up-left, `focus` down, etc. — a function of
   the artwork, not a bug.
5. **`stageScale` is a whole-image swell.** It cannot produce the
   "secondary motion" the Bible describes (follow-through, overlapping
   motion); only a rigged asset can.
6. **Lottie seam untested with real art.** No available Lottie assets
   exist, so that branch is exercised only by its error path.
