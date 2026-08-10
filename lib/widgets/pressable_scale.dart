import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// Wraps [child] with a subtle scale-down-on-press affordance — generic
/// tactile feedback for anything tappable (cards, badges, chips) that
/// doesn't already get its own press animation from a Material widget.
///
/// Pass [onTap] when this widget should own the tap gesture itself (it then
/// drives the scale from the same [GestureDetector] that reports the tap, so
/// there's exactly one gesture owner and no arena conflict with an inner
/// `InkWell`). Omit [onTap] when [child] already handles its own tap deeper
/// in the tree (e.g. it's just wrapped for a passive hover/tooltip target) —
/// in that mode this widget only observes pointer events for the scale
/// visual and never claims the gesture.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scaled = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1.0,
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onTap,
        child: scaled,
      );
    }

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: scaled,
    );
  }
}
