import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// A count-up/count-down [Text] that eases toward a new numeric value
/// instead of jumping — for stat tiles and progress labels.
///
/// [formatter] controls how the animated numeric value is rendered (e.g.
/// rounding to an int, adding a unit suffix); it receives the raw
/// intermediate `double` on every animation frame.
class AnimatedCountText extends StatelessWidget {
  const AnimatedCountText({
    super.key,
    required this.value,
    this.formatter,
    this.style,
    this.textAlign,
  });

  final num value;
  final String Function(double value)? formatter;
  final TextStyle? style;
  final TextAlign? textAlign;

  static String _defaultFormat(double v) => v.round().toString();

  @override
  Widget build(BuildContext context) {
    final format = formatter ?? _defaultFormat;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AppDurations.slow,
      curve: AppCurves.standard,
      builder: (context, animatedValue, _) {
        return Text(format(animatedValue), style: style, textAlign: textAlign);
      },
    );
  }
}
