import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// A chevron that rotates between collapsed/expanded instead of popping
/// between two static icons — the common "tap header to expand/collapse a
/// group" affordance (category headers, nested project trees, ...).
class AnimatedExpandIcon extends StatelessWidget {
  const AnimatedExpandIcon({
    super.key,
    required this.expanded,
    this.icon = Icons.expand_more,
    this.size,
    this.color,
  });

  final bool expanded;
  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      child: Icon(icon, size: size, color: color),
    );
  }
}
