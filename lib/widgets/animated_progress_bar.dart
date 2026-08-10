import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// A [LinearProgressIndicator] whose `value` eases to a new target instead
/// of jumping, via an internal [TweenAnimationBuilder] (no ticker/controller
/// bookkeeping needed by the caller).
///
/// Deliberately takes no size parameters beyond what [LinearProgressIndicator]
/// itself takes ([minHeight]) — this widget must never change the layout
/// footprint its container already reserves for it (some call sites pin an
/// exact-width `leading` box around a progress+label pair independent of
/// which label variant is showing, so any extra sizing behavior here would
/// reintroduce the width-jump this widget is meant to avoid).
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.minHeight,
    this.color,
    this.backgroundColor,
    this.borderRadius,
  });

  /// `null` renders an indeterminate bar, same as [LinearProgressIndicator].
  final double? value;
  final double? minHeight;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final target = value;
    Widget bar(double? v) {
      final indicator = LinearProgressIndicator(
        value: v,
        minHeight: minHeight,
        color: color,
        backgroundColor: backgroundColor,
      );
      return borderRadius == null
          ? indicator
          : ClipRRect(borderRadius: borderRadius!, child: indicator);
    }

    if (target == null) return bar(null);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: AppDurations.medium,
      curve: AppCurves.standard,
      builder: (context, animatedValue, _) => bar(animatedValue),
    );
  }
}
