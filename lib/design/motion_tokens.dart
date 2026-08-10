import 'package:flutter/animation.dart';

/// Shared animation durations. Codifies the 150–250ms range already in
/// informal use across consuming apps' hand-rolled `AnimatedSize`/
/// `AnimatedSwitcher` calls, so new and existing animations agree.
class AppDurations {
  const AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

/// Shared animation curves.
class AppCurves {
  const AppCurves._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve entrance = Curves.easeOut;
}
