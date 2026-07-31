import 'package:flutter/material.dart';

/// Current version of the theme JSON format (see docs/theme-schema.md).
const int kThemeSchemaVersion = 1;

/// The Material color roles serialized by [ThemeSchema], in editor order.
/// Portable: any app that maps these role names to its own color system can
/// consume a theme file produced by this schema.
const List<String> kThemeRoles = [
  'primary',
  'onPrimary',
  'primaryContainer',
  'onPrimaryContainer',
  'secondary',
  'onSecondary',
  'secondaryContainer',
  'onSecondaryContainer',
  'tertiary',
  'onTertiary',
  'tertiaryContainer',
  'onTertiaryContainer',
  'error',
  'onError',
  'errorContainer',
  'onErrorContainer',
  'surface',
  'onSurface',
  'surfaceContainerHighest',
  'onSurfaceVariant',
  'outline',
  'outlineVariant',
  'inverseSurface',
  'onInverseSurface',
  'inversePrimary',
  'shadow',
  'scrim',
  'surfaceTint',
];

/// The most impactful roles surfaced in the theme editor's "basic" view.
const List<String> kPrimaryEditorRoles = [
  'primary',
  'onPrimary',
  'secondary',
  'tertiary',
  'error',
  'surface',
  'onSurface',
  'surfaceContainerHighest',
];

/// An open, versioned representation of a color theme: a brightness plus a map
/// of Material color roles to ARGB values.
class ThemeSchema {
  ThemeSchema({
    required this.name,
    required this.brightness,
    required Map<String, int> colors,
    this.version = kThemeSchemaVersion,
  }) : colors = Map.of(colors);

  final String name;
  final Brightness brightness;
  final Map<String, int> colors;
  final int version;

  ThemeSchema copyWith({
    String? name,
    Brightness? brightness,
    Map<String, int>? colors,
  }) {
    return ThemeSchema(
      name: name ?? this.name,
      brightness: brightness ?? this.brightness,
      colors: colors ?? this.colors,
      version: version,
    );
  }

  /// Builds a [ThemeSchema] from a Material [ColorScheme].
  factory ThemeSchema.fromColorScheme(String name, ColorScheme s) {
    return ThemeSchema(
      name: name,
      brightness: s.brightness,
      colors: {
        'primary': _argb(s.primary),
        'onPrimary': _argb(s.onPrimary),
        'primaryContainer': _argb(s.primaryContainer),
        'onPrimaryContainer': _argb(s.onPrimaryContainer),
        'secondary': _argb(s.secondary),
        'onSecondary': _argb(s.onSecondary),
        'secondaryContainer': _argb(s.secondaryContainer),
        'onSecondaryContainer': _argb(s.onSecondaryContainer),
        'tertiary': _argb(s.tertiary),
        'onTertiary': _argb(s.onTertiary),
        'tertiaryContainer': _argb(s.tertiaryContainer),
        'onTertiaryContainer': _argb(s.onTertiaryContainer),
        'error': _argb(s.error),
        'onError': _argb(s.onError),
        'errorContainer': _argb(s.errorContainer),
        'onErrorContainer': _argb(s.onErrorContainer),
        'surface': _argb(s.surface),
        'onSurface': _argb(s.onSurface),
        'surfaceContainerHighest': _argb(s.surfaceContainerHighest),
        'onSurfaceVariant': _argb(s.onSurfaceVariant),
        'outline': _argb(s.outline),
        'outlineVariant': _argb(s.outlineVariant),
        'inverseSurface': _argb(s.inverseSurface),
        'onInverseSurface': _argb(s.onInverseSurface),
        'inversePrimary': _argb(s.inversePrimary),
        'shadow': _argb(s.shadow),
        'scrim': _argb(s.scrim),
        'surfaceTint': _argb(s.surfaceTint),
      },
    );
  }

  Color role(String key, [Color fallback = const Color(0xFF000000)]) {
    final v = colors[key];
    return v == null ? fallback : Color(v);
  }

  /// Reconstructs a Material [ColorScheme]. Missing roles fall back to a
  /// seed-derived scheme so partial/foreign files still produce a valid theme.
  ColorScheme toColorScheme() {
    final base = ColorScheme.fromSeed(
      seedColor: role('primary', const Color(0xFF5C6BC0)),
      brightness: brightness,
    );
    Color r(String k, Color fb) => colors.containsKey(k) ? Color(colors[k]!) : fb;
    return base.copyWith(
      primary: r('primary', base.primary),
      onPrimary: r('onPrimary', base.onPrimary),
      primaryContainer: r('primaryContainer', base.primaryContainer),
      onPrimaryContainer: r('onPrimaryContainer', base.onPrimaryContainer),
      secondary: r('secondary', base.secondary),
      onSecondary: r('onSecondary', base.onSecondary),
      secondaryContainer: r('secondaryContainer', base.secondaryContainer),
      onSecondaryContainer:
          r('onSecondaryContainer', base.onSecondaryContainer),
      tertiary: r('tertiary', base.tertiary),
      onTertiary: r('onTertiary', base.onTertiary),
      tertiaryContainer: r('tertiaryContainer', base.tertiaryContainer),
      onTertiaryContainer: r('onTertiaryContainer', base.onTertiaryContainer),
      error: r('error', base.error),
      onError: r('onError', base.onError),
      errorContainer: r('errorContainer', base.errorContainer),
      onErrorContainer: r('onErrorContainer', base.onErrorContainer),
      surface: r('surface', base.surface),
      onSurface: r('onSurface', base.onSurface),
      surfaceContainerHighest:
          r('surfaceContainerHighest', base.surfaceContainerHighest),
      onSurfaceVariant: r('onSurfaceVariant', base.onSurfaceVariant),
      outline: r('outline', base.outline),
      outlineVariant: r('outlineVariant', base.outlineVariant),
      inverseSurface: r('inverseSurface', base.inverseSurface),
      onInverseSurface: r('onInverseSurface', base.onInverseSurface),
      inversePrimary: r('inversePrimary', base.inversePrimary),
      shadow: r('shadow', base.shadow),
      scrim: r('scrim', base.scrim),
      surfaceTint: r('surfaceTint', base.surfaceTint),
    );
  }

  ThemeData toThemeData() {
    return ThemeData(
      colorScheme: toColorScheme(),
      useMaterial3: true,
      brightness: brightness,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': version,
      'name': name,
      'brightness': brightness == Brightness.dark ? 'dark' : 'light',
      'colors': {
        for (final entry in colors.entries) entry.key: _hex(entry.value),
      },
    };
  }

  /// Parses a theme JSON document. Throws [FormatException] on invalid input.
  factory ThemeSchema.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int) {
      throw const FormatException('Missing or invalid "schemaVersion".');
    }
    if (version > kThemeSchemaVersion) {
      throw FormatException(
          'Theme was made with a newer app (schema v$version).');
    }
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Missing "name".');
    }
    final brightness =
        (json['brightness'] == 'dark') ? Brightness.dark : Brightness.light;
    final rawColors = json['colors'];
    if (rawColors is! Map) {
      throw const FormatException('Missing "colors" map.');
    }
    final colors = <String, int>{};
    rawColors.forEach((k, v) {
      final parsed = _parseHex(v);
      if (parsed != null) colors[k as String] = parsed;
    });
    if (colors['primary'] == null) {
      throw const FormatException('Theme must define at least "primary".');
    }
    return ThemeSchema(
      name: name.trim(),
      brightness: brightness,
      colors: colors,
      version: version,
    );
  }

  // --- Color <-> ARGB int / hex helpers ---

  static int _argb(Color c) =>
      ((c.a * 255).round() & 0xff) << 24 |
      ((c.r * 255).round() & 0xff) << 16 |
      ((c.g * 255).round() & 0xff) << 8 |
      ((c.b * 255).round() & 0xff);

  static String _hex(int argb) =>
      '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static int? _parseHex(dynamic value) {
    if (value is! String) return null;
    var s = value.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s'; // assume opaque
    if (s.length != 8) return null;
    return int.tryParse(s, radix: 16);
  }
}
