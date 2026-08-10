import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../design/motion_tokens.dart';

/// The shared "modern card" building block for list-style content (task
/// tiles, category rows, stat tiles, ...): a themed [Card] (radius/elevation/
/// surface color come from `applyComponentThemes` — see
/// `theming/component_themes.dart`) with an [InkWell] for ripple/tap and a
/// subtle press-scale, so every list screen that adopts it looks and feels
/// consistent without each one reimplementing tap feedback.
///
/// [onTap] and [onLongPress] are optional — a non-interactive card (e.g. a
/// pure stat display) can omit both and still get the card surface styling.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null || widget.onLongPress != null;
    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: AnimatedScale(
        scale: interactive && _pressed ? 0.98 : 1.0,
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        child: Card(
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onHighlightChanged: interactive ? _setPressed : null,
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
