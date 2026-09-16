/// VaaniX V1 Design System — Radius Tokens
///
/// Standardized border radii across cards, buttons, chips, and modals.
library;

import 'package:flutter/material.dart';

abstract final class VaaniXRadius {
  /// 8px — small tags, mini pills
  static const double sm = 8.0;
  static const Radius radiusSm = Radius.circular(sm);
  static const BorderRadius borderSm = BorderRadius.all(radiusSm);

  /// 12px — inputs, secondary chips, compact cards
  static const double md = 12.0;
  static const Radius radiusMd = Radius.circular(md);
  static const BorderRadius borderMd = BorderRadius.all(radiusMd);

  /// 16px — standard Stitch cards, buttons, dialogs
  static const double lg = 16.0;
  static const Radius radiusLg = Radius.circular(lg);
  static const BorderRadius borderLg = BorderRadius.all(radiusLg);

  /// 24px — hero cards, modal sheets, drawer containers
  static const double xl = 24.0;
  static const Radius radiusXl = Radius.circular(xl);
  static const BorderRadius borderXl = BorderRadius.all(radiusXl);

  /// 999px — full pill / badges / avatars
  static const double pill = 999.0;
  static const Radius radiusPill = Radius.circular(pill);
  static const BorderRadius borderPill = BorderRadius.all(radiusPill);
}
