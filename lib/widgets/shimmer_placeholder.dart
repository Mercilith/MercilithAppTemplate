import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/design_tokens.dart';

/// A skeleton-loading placeholder — a rounded, softly-shimmering block —
/// for screens whose current loading state is a bare [CircularProgressIndicator].
/// Repeats indefinitely; swap it out for the real content once loaded.
class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadii.sm),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: const Duration(milliseconds: 1200),
          color: scheme.surface.withValues(alpha: 0.6),
        );
  }
}
