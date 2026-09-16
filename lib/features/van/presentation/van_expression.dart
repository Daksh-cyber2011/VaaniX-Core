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
  });

  /// Stable asset id (internal `van_` prefix; `duck` stays the character
  /// code name for animation assets — see `docs/VAN/Implementation.md`).
  final String id;

  /// Which canonical expression this artwork represents.
  final VanExpression expression;

  /// Bundle path of the PNG (transparent background preserved as supplied).
  final String path;

  /// Intrinsic pixel size of the supplied artwork. Used for reasoning about
  /// aspect ratio only — rendering always uses [BoxFit.contain], so the
  /// original proportions can never stretch or squash.
  final int width;
  final int height;

  final bool available;

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
      other.available == available;

  @override
  int get hashCode =>
      Object.hash(id, expression, path, width, height, available);
}

/// The canonical expression set as supplied, with the exact bundle paths and
/// intrinsic dimensions of the PNGs. `available` is true: this artwork IS the
/// approved canonical set committed to the repository.
///
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
  ),
  VanExpressionArt(
    id: 'van_expression_thinking',
    expression: VanExpression.thinking,
    path: 'assets/van/expressions/thinking.png',
    width: 1024,
    height: 1536,
    available: true,
  ),
  VanExpressionArt(
    id: 'van_expression_happy',
    expression: VanExpression.happy,
    path: 'assets/van/expressions/happy.png',
    width: 1024,
    height: 1536,
    available: true,
  ),
  VanExpressionArt(
    id: 'van_expression_excited',
    expression: VanExpression.excited,
    path: 'assets/van/expressions/excited.png',
    width: 1024,
    height: 1536,
    available: true,
  ),
  VanExpressionArt(
    id: 'van_expression_motivating',
    expression: VanExpression.motivating,
    path: 'assets/van/expressions/motivating.png',
    width: 1024,
    height: 1536,
    available: true,
  ),
  VanExpressionArt(
    id: 'van_expression_confused',
    expression: VanExpression.confused,
    path: 'assets/van/expressions/confused.png',
    width: 1024,
    height: 1536,
    available: true,
  ),
  VanExpressionArt(
    id: 'van_expression_sleepy',
    expression: VanExpression.sleepy,
    path: 'assets/van/expressions/sleepy.png',
    width: 1199,
    height: 1312,
    available: true,
  ),
  VanExpressionArt(
    id: 'van_expression_achievement',
    expression: VanExpression.achievement,
    path: 'assets/van/expressions/achievement.png',
    width: 1024,
    height: 1536,
    available: true,
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
