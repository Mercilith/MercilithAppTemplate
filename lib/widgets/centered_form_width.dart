import 'package:flutter/material.dart';

/// Caps a form's width and centers it, so a form built for a phone-width
/// screen doesn't stretch into an uncomfortably wide single column on a wide
/// desktop window. A no-op on any screen narrower than [maxWidth] (i.e.
/// every phone), so it's safe to wrap unconditionally.
class CenteredFormWidth extends StatelessWidget {
  const CenteredFormWidth({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
