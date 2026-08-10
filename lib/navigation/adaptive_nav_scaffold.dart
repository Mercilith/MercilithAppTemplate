import 'package:flutter/material.dart';

import '../design/motion_tokens.dart';

/// Icon/label data for one destination in [AdaptiveNavScaffold].
class NavDestinationData {
  const NavDestinationData(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Width, in logical pixels, above which [AdaptiveNavScaffold] switches from
/// a bottom [NavigationBar] to a side [NavigationRail] (Material's guidance
/// for when a rail suits the available width better than a bottom bar).
const double kAdaptiveNavWideBreakpoint = 840;

/// A [Scaffold] whose primary navigation chrome adapts to the available
/// width: a bottom [NavigationBar] below [kAdaptiveNavWideBreakpoint], a side
/// [NavigationRail] at or above it. [body] and [destinations] are identical
/// either way — only the chrome changes.
class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    super.key,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.floatingActionButton,
  });

  final Widget body;
  final List<NavDestinationData> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kAdaptiveNavWideBreakpoint;
        final Widget scaffold;
        if (!wide) {
          scaffold = Scaffold(
            body: body,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          );
        } else {
          scaffold = Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
            floatingActionButton: floatingActionButton,
          );
        }
        // Cross-fades the bar<->rail chrome switch instead of an instant pop
        // when a resizable window (e.g. TaskApp's Windows build) crosses
        // kAdaptiveNavWideBreakpoint.
        return AnimatedSwitcher(
          duration: AppDurations.medium,
          switchInCurve: AppCurves.entrance,
          switchOutCurve: AppCurves.entrance,
          child: KeyedSubtree(key: ValueKey(wide), child: scaffold),
        );
      },
    );
  }
}
