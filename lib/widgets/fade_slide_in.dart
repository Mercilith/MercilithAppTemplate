import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// A one-shot entrance animation: fades and slides [child] up slightly from
/// [offset] into place. Plays once on mount (driven by an internal
/// [TweenAnimationBuilder], no [AnimationController]/ticker bookkeeping
/// needed by the caller) — re-mounting (a new [Key]) replays it.
///
/// [delay] lets a list of these be staggered by giving each successive item
/// an incrementing delay; see [staggerFadeIn].
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppDurations.medium,
    this.offset = 12,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting vertical offset, in logical pixels, that eases to zero.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _started = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _started = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _started ? 1.0 : 0.0),
      duration: widget.duration,
      curve: AppCurves.entrance,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
