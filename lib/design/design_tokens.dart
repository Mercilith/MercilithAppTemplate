/// Shared corner-radius scale. Replaces the ad hoc `BorderRadius.circular(n)`
/// literals (2–24px, no consistent pattern) that had accumulated per-screen
/// in consuming apps before this package had a design-token layer.
class AppRadii {
  const AppRadii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Fully rounded ("pill") — for chips/badges that should always render as
  /// a stadium shape regardless of their height.
  static const double pill = 999;
}

/// Shared spacing scale, in logical pixels. Replaces raw `EdgeInsets`/
/// `SizedBox` literals scattered per-screen in consuming apps.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
