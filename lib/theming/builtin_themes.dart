import 'package:flutter/material.dart';

import '../db/theme_kind.dart';
import 'theme_schema.dart';

/// Definition of a built-in theme: its stable key, kind and generated schema.
class BuiltInTheme {
  const BuiltInTheme(this.key, this.kind, this.schema);

  /// Stable identity, meant to be stored in a `builtinKey`-style column.
  /// Never change an existing key: it is what a unique index typically uses
  /// to keep seeding idempotent across concurrently-opening isolates.
  final String key;

  final ThemeKind kind;
  final ThemeSchema schema;
}

/// Display names of the original 12 built-ins, keyed by [BuiltInTheme.key].
///
/// Frozen on purpose: useful for a migration matching already-seeded rows by
/// display name if a `builtinKey` column is added after rows already exist.
/// Renaming a built-in means changing [buildBuiltInThemes], not this map.
const Map<String, String> kV5BuiltInNames = {
  'indigo_light': 'Indigo Light',
  'teal_light': 'Teal Light',
  'rose_light': 'Rose Light',
  'amber_light': 'Amber Light',
  'indigo_dark': 'Indigo Dark',
  'teal_dark': 'Teal Dark',
  'rose_dark': 'Rose Dark',
  'amber_dark': 'Amber Dark',
  'mono_light': 'Mono Light',
  'mono_dark': 'Mono Dark',
  'slate_light': 'Slate Light',
  'slate_dark': 'Slate Dark',
};

/// The 12 built-in themes: 4 light, 4 dark, 4 monochrome.
List<BuiltInTheme> buildBuiltInThemes() {
  ThemeSchema seeded(
    String name,
    Color seed,
    Brightness brightness, {
    DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: variant,
    );
    return ThemeSchema.fromColorScheme(name, scheme);
  }

  return [
    // 4 light
    BuiltInTheme('indigo_light', ThemeKind.builtInLight,
        seeded('Indigo Light', const Color(0xFF5C6BC0), Brightness.light)),
    BuiltInTheme('teal_light', ThemeKind.builtInLight,
        seeded('Teal Light', const Color(0xFF00897B), Brightness.light)),
    BuiltInTheme('rose_light', ThemeKind.builtInLight,
        seeded('Rose Light', const Color(0xFFD81B60), Brightness.light)),
    BuiltInTheme('amber_light', ThemeKind.builtInLight,
        seeded('Amber Light', const Color(0xFFF9A825), Brightness.light)),

    // 4 dark
    BuiltInTheme('indigo_dark', ThemeKind.builtInDark,
        seeded('Indigo Dark', const Color(0xFF5C6BC0), Brightness.dark)),
    BuiltInTheme('teal_dark', ThemeKind.builtInDark,
        seeded('Teal Dark', const Color(0xFF00897B), Brightness.dark)),
    BuiltInTheme('rose_dark', ThemeKind.builtInDark,
        seeded('Rose Dark', const Color(0xFFD81B60), Brightness.dark)),
    BuiltInTheme('amber_dark', ThemeKind.builtInDark,
        seeded('Amber Dark', const Color(0xFFF9A825), Brightness.dark)),

    // 4 monochrome (2 light, 2 dark; grayscale / near-neutral)
    BuiltInTheme(
        'mono_light',
        ThemeKind.builtInMonochrome,
        seeded('Mono Light', const Color(0xFF000000), Brightness.light,
            variant: DynamicSchemeVariant.monochrome)),
    BuiltInTheme(
        'mono_dark',
        ThemeKind.builtInMonochrome,
        seeded('Mono Dark', const Color(0xFF000000), Brightness.dark,
            variant: DynamicSchemeVariant.monochrome)),
    BuiltInTheme(
        'slate_light',
        ThemeKind.builtInMonochrome,
        seeded('Slate Light', const Color(0xFF546E7A), Brightness.light,
            variant: DynamicSchemeVariant.neutral)),
    BuiltInTheme(
        'slate_dark',
        ThemeKind.builtInMonochrome,
        seeded('Slate Dark', const Color(0xFF546E7A), Brightness.dark,
            variant: DynamicSchemeVariant.neutral)),
  ];
}
