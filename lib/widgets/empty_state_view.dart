import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'fade_slide_in.dart';

/// The shared "nothing here yet" pattern: a large icon, a title, and an
/// optional secondary hint, with a soft fade/slide entrance — replaces the
/// several near-duplicate empty-state implementations that had accumulated
/// per-screen in consuming apps.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 64,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeSlideIn(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: theme.hintColor),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
