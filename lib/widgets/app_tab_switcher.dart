import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// A fade-through transition between tab bodies, keyed on [index] — a
/// drop-in replacement for `IndexedStack` where the instant swap between
/// bottom-nav tabs should read as a soft cross-fade instead of a hard pop.
///
/// Unlike `IndexedStack`, only the active child is kept in the tree — each
/// tab is expected to hold its own state via a state-management layer
/// (Riverpod providers, etc.), not transient local widget state that needs
/// to survive being unmounted while another tab is active.
class AppTabSwitcher extends StatelessWidget {
  const AppTabSwitcher({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      duration: AppDurations.medium,
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        return FadeThroughTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey(index),
        child: children[index],
      ),
    );
  }
}
