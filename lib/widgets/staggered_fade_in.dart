import 'package:flutter/widgets.dart';

import 'fade_slide_in.dart';

/// Wraps each of [children] in a [FadeSlideIn] with an incrementing delay,
/// so a list/grid's first appearance reads as a soft cascade rather than
/// everything popping in at once.
///
/// [step] is the delay added per item; [maxDelay] caps the stagger so a very
/// long list doesn't leave its last items waiting seconds to animate in —
/// items beyond the cap all start at [maxDelay].
List<Widget> staggerFadeIn(
  List<Widget> children, {
  Duration step = const Duration(milliseconds: 30),
  Duration maxDelay = const Duration(milliseconds: 300),
}) {
  return [
    for (var i = 0; i < children.length; i++)
      FadeSlideIn(
        delay: _clampDelay(step * i, maxDelay),
        child: children[i],
      ),
  ];
}

Duration _clampDelay(Duration d, Duration max) => d > max ? max : d;
