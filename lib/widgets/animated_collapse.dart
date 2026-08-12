import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// Smoothly grows/shrinks [child] as [expanded] toggles, instead of it
/// popping in/out instantly — the collapse-side counterpart to
/// [AnimatedExpandIcon]'s chevron rotation, for the same "tap a header to
/// expand/collapse a group" affordance (category headers, nested project
/// trees, settings sub-sections, ...).
///
/// Unlike [AnimatedCrossFade] (which mounts *both* children for the whole
/// transition — see TaskApp's own CLAUDE.md toolchain gotcha #24 for why
/// that's a real trap when either side carries live `Form` state), [child]
/// here is a single widget that stays mounted throughout: only its
/// effective height (via [AnimatedAlign]'s `heightFactor`) and opacity
/// animate, clipped by the surrounding [ClipRect] so the collapsing content
/// doesn't paint outside its shrinking box. Safe to use even when [child]
/// contains `Form` fields, since there's never a second, hidden copy of it
/// registered with an ancestor `Form`.
class AnimatedCollapse extends StatelessWidget {
  const AnimatedCollapse({
    super.key,
    required this.expanded,
    required this.child,
    this.duration = AppDurations.medium,
    this.curve = AppCurves.standard,
  });

  final bool expanded;
  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: duration,
        curve: curve,
        alignment: Alignment.topCenter,
        heightFactor: expanded ? 1 : 0,
        child: AnimatedOpacity(
          duration: duration,
          curve: curve,
          opacity: expanded ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}
