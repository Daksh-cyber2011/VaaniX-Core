/// Canonical VAN expression identities of the supplied artwork.
///
/// The eight canonical expression images (`assets/van/expressions/*.png`)
/// are the visual source of truth for Van's static appearance. This enum is
/// the stable *semantic* handle for that artwork: UI code and tests reference
/// [VanExpression], never raw asset paths.
///
/// The artwork itself is canonical — body proportions, colours, clothing,
/// goggles, headphones and beak are displayed exactly as supplied. Only the
/// original file names were normalised to the semantic names below
/// (provenance for every file is recorded in
/// `assets/van/metadata/van_assets.json`).
library;

import 'package:flutter/foundation.dart';

import 'package:vaanix_app/features/van/domain/van_state.dart';

/// The eight canonical expressions of the supplied VAN art set.
enum VanExpression {
  neutral,
  thinking,
  happy,
  excited,
  motivating,
  confused,
  sleepy,
  achievement,
}

/// Immutable metadata for one canonical expression image.
@immutable
class VanExpressionArt {
  const VanExpressionArt({
    required this.id,
    required this.expression,
    required this.path,
    required this.width,
    required this.height,
    this.available = false,
    this.frame = VanExpressionFrame.wholeImage,
  });

  /// Stable asset id (internal `van_` prefix; `duck` stays the character
  /// code name for animation assets — see `docs/VAN/Implementation.md`).
  final String id;

  /// Which canonical expression this artwork represents.
  final VanExpression expression;

  /// Bundle path of the PNG (transparent background preserved as supplied).
  final String path;

  /// Intrinsic pixel size of the supplied artwork.
  final int width;
  final int height;

  final bool available;

  /// The character-bearing region of [path], in source pixels.
  ///
  /// See [VanExpressionFrame] for why this exists.
  final VanExpressionFrame frame;

  bool get isAvailable => available && path.isNotEmpty;

  /// Human-readable expression name for accessibility labels, e.g.
  /// `thinking`, `excited`, `confused`.
  String get label => expression.name;

  @override
  bool operator ==(Object other) =>
      other is VanExpressionArt &&
      other.id == id &&
      other.expression == expression &&
      other.path == path &&
      other.width == width &&
      other.height == height &&
      other.available == available &&
      other.frame == frame;

  @override
  int get hashCode => Object.hash(
        id,
        expression,
        path,
        width,
        height,
        available,
        frame,
      );
}

/// The character-bearing rectangle inside a canonical expression PNG.
///
/// ## Why this exists
///
/// The supplied artwork is cut out inconsistently. Measuring every
/// asset's non-transparent bounding box shows the character occupies
/// between **0.523 and 0.635** of the stage width depending on the
/// expression (a 21% spread), because `excited.png` has its arms spread
/// while `motivating.png` has them tucked in, and because
/// `sleepy.png` was supplied on a differently-sized canvas
/// (1199×1312 versus 1024×1536 for the other seven).
///
/// A plain `BoxFit.contain` scales by *canvas* size, so the character's
/// apparent size and vertical position both change with the expression:
/// on a 160 px stage `excited` renders 101.6 px wide while `motivating`
/// renders 83.6 px. That reads as VAN popping and jumping on every state
/// change — precisely the "five slightly different ducks" failure.
///
/// Cropping each expression to its measured character frame before
/// rendering removes the dead transparent margin, so every expression
/// fills the stage identically. This is the standard per-frame trim used
/// in sprite pipelines: it changes *framing* only, never the pixels
/// inside the frame, so the artwork is still displayed exactly as
/// supplied.
///
/// Frames are measured offline by `tools/png_character_extent.py` and
/// committed as data — nothing is decoded at runtime.
@immutable
class VanExpressionFrame {
  const VanExpressionFrame({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// The whole image. Used when no measurement is available, which
  /// degrades to the original contain-fit behaviour.
  static const VanExpressionFrame wholeImage = VanExpressionFrame(
    left: 0,
    top: 0,
    width: 0,
    height: 0,
  );

  /// Pixel offsets of the character box inside the source image.
  final int left;
  final int top;
  final int width;
  final int height;

  /// True when this frame covers the entire source image, i.e. no
  /// normalisation should be applied.
  bool get isWholeImage => width <= 0 || height <= 0;

  @override
  bool operator ==(Object other) =>
      other is VanExpressionFrame &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() =>
      'VanExpressionFrame($left, $top, ${width}x$height)';
}

/// The canonical expression set as supplied, with the exact bundle paths and
/// intrinsic dimensions of the PNGs. `available` is true: this artwork IS the
/// approved canonical set committed to the repository.
///
/// Each entry also carries a measured [VanExpressionFrame] — the tight
/// non-transparent bounding box of that PNG, expanded by a small uniform
/// margin so soft antialiased edges are never clipped. The renderer crops to
/// this box before display, which is what keeps VAN the same apparent size
/// and position across every expression. Regenerate with:
/// ```sh
/// python tools/png_character_extent.py
/// ```
/// `canonicalSource` provenance (original supplied file name -> bundle path):
///   Neutral VAN.png                -> neutral.png
///   Thinking VAN.png               -> thinking.png
///   Happy VAN.png                  -> happy.png
///   Excited VAN.png                -> excited.png
///   Motivating VAN.png             -> motivating.png
///   Confused VAN.png               -> confused.png
///   Tired or Sad VAN.png           -> sleepy.png
///   SUPER HAPPY OR CHEERFUL VAN.png-> achievement.png
const List<VanExpressionArt> kVanCanonicalExpressionArt = <VanExpressionArt>[
  VanExpressionArt(
    id: 'van_expression_neutral',
    expression: VanExpression.neutral,
    path: 'assets/van/expressions/neutral.png',
    width: 1024,
    height: 1536,
    available: true,
    // measured bbox 69,82 883x1426
    frame: VanExpressionFrame(left: 61, top: 74, width: 899, height: 1442),
  ),
  VanExpressionArt(
    id: 'van_expression_thinking',
    expression: VanExpression.thinking,
    path: 'assets/van/expressions/thinking.png',
    width: 1024,
    height: 1536,
    available: true,
    // measured bbox 116,48 810x1444
    frame: VanExpressionFrame(left: 108, top: 40, width: 826, height: 1460),
  ),
  VanExpressionArt(
    id: 'van_expression_happy',
    expression: VanExpression.happy,
    path: 'assets/van/expressions/happy.png',
    width: 1024,
    height: 1536,
    available: true,
    // measured bbox 41,86 943x1422
    frame: VanExpressionFrame(left: 33, top: 78, width: 959, height: 1438),
  ),
  VanExpressionArt(
    id: 'van_expression_excited',
    expression: VanExpression.excited,
    path: 'assets/van/expressions/excited.png',
    width: 1024,
    height: 1536,
    available: true,
    // measured bbox 30,86 975x1396
    frame: VanExpressionFrame(left: 22, top: 78, width: 991, height: 1412),
  ),
  VanExpressionArt(
    id: 'van_expression_motivating',
    expression: VanExpression.motivating,
    path: 'assets/van/expressions/motivating.png',
    width: 1024,
    height: 1536,
    available: true,
    // measured bbox 103,64 803x1423
    frame: VanExpressionFrame(left: 95, top: 56, width: 819, height: 1439),
  ),
  VanExpressionArt(
    id: 'van_expression_confused',
    expression: VanExpression.confused,
    path: 'assets/van/expressions/confused.png',
    width: 1024,
    height: 1536,
    available: true,
    // measured bbox 113,61 833x1445
    frame: VanExpressionFrame(left: 105, top: 53, width: 849, height: 1461),
  ),
  VanExpressionArt(
    id: 'van_expression_sleepy',
    expression: VanExpression.sleepy,
    path: 'assets/van/expressions/sleepy.png',
    width: 1199,
    height: 1312,
    available: true,
    // measured bbox 272,74 687x1148 (canvas differs from the other seven)
    frame: VanExpressionFrame(left: 264, top: 66, width: 703, height: 1164),
  ),
  VanExpressionArt(
    id: 'van_expression_achievement',
    expression: VanExpression.achievement,
    path: 'assets/van/expressions/achievement.png',
    width: 1024,
    height: 1536,
    available: true,
    // measured bbox 41,127 930x1339
    frame: VanExpressionFrame(left: 33, top: 119, width: 946, height: 1355),
  ),
];

/// Deterministic mapping from Van's presentation states to the closest
/// canonical expression of the supplied artwork.
///
/// The state vocabulary (and its priority/interruptibility system) is
/// intentionally untouched; this mapping only decides which canonical
/// expression best represents each state visually:
///
///   idle      -> neutral     (relaxed, available companion)
///   happy     -> happy       (warm acknowledgement)
///   thinking  -> thinking    (considering / processing / waiting)
///   focus     -> thinking    (calm engaged concentration)
///   caring    -> motivating  (gentle supportive encouragement)
///   surprised -> excited     (delighted surprise)
///   sad       -> sleepy      (supplied art covers tired-or-sad, mild)
///   funny     -> happy       (brief playful moment)
///   achievement -> achievement (celebration)
///   speaking  -> motivating  (actively guiding / delivering a response)
///   error     -> confused    (gentle, recoverable problem)
///
/// Every canonical expression is reachable from at least one state, so no
/// supplied artwork is dead weight.
extension VanStateExpressionX on VanState {
  VanExpression get canonicalExpression => switch (this) {
        VanState.idle => VanExpression.neutral,
        VanState.happy => VanExpression.happy,
        VanState.thinking => VanExpression.thinking,
        VanState.focus => VanExpression.thinking,
        VanState.caring => VanExpression.motivating,
        VanState.surprised => VanExpression.excited,
        VanState.sad => VanExpression.sleepy,
        VanState.funny => VanExpression.happy,
        VanState.achievement => VanExpression.achievement,
        VanState.speaking => VanExpression.motivating,
        VanState.error => VanExpression.confused,
      };
}
