import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// A row of pill-shaped progress dots — the active dot widens and picks up
/// the theme's primary color, inactive dots stay small and muted. Shared by
/// any multi-step flow (a wizard, an onboarding carousel, ...) so the
/// pattern isn't reimplemented per screen.
class StepProgressDots extends StatelessWidget {
  const StepProgressDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.dotHeight = 8,
    this.activeWidth = 20,
    this.inactiveWidth = 8,
    this.spacing = 6,
  });

  final int count;
  final int activeIndex;
  final double dotHeight;
  final double activeWidth;
  final double inactiveWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppCurves.standard,
            width: i == activeIndex ? activeWidth : inactiveWidth,
            height: dotHeight,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(dotHeight / 2),
            ),
          ),
        ],
      ],
    );
  }
}
