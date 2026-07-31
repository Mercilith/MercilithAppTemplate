import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/theme_repository.dart';
import '../theme_schema.dart';

/// A theme row paired with its parsed schema.
class ParsedTheme {
  const ParsedTheme({required this.row, required this.schema});
  final ThemeRow row;
  final ThemeSchema schema;
}

ThemeSchema _parse(ThemeRow row) {
  try {
    return ThemeSchema.fromJson(
        jsonDecode(row.schemeJson) as Map<String, dynamic>);
  } catch (_) {
    // Corrupt row: fall back to a safe default so the app still themes.
    return ThemeSchema.fromColorScheme(
      row.name,
      ColorScheme.fromSeed(seedColor: const Color(0xFF5C6BC0)),
    );
  }
}

/// The host app must override this with its concrete [ThemeRepository]
/// implementation (see this repo's CLAUDE.md, "The Drift cross-package
/// pattern") — e.g. in the app's `ProviderScope(overrides: [...])`.
final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  throw UnimplementedError(
      'Override themeRepositoryProvider with a concrete ThemeRepository.');
});

/// The host app must override this to read wherever it stores the active
/// theme id (e.g. a settings row) — typically by watching its own settings
/// provider inside the override.
final activeThemeIdProvider = Provider<int?>((ref) {
  throw UnimplementedError(
      'Override activeThemeIdProvider to read the host app\'s active theme id.');
});

/// The host app must override this to persist a newly-applied theme id
/// wherever [activeThemeIdProvider] reads it from.
typedef PersistActiveThemeId = Future<void> Function(
    WidgetRef ref, int themeId);
final persistActiveThemeIdProvider = Provider<PersistActiveThemeId>((ref) {
  throw UnimplementedError(
      'Override persistActiveThemeIdProvider to persist the active theme id.');
});

/// Optional: a side effect to run after a theme is applied (e.g. refreshing
/// a home-screen widget). Defaults to a no-op — override only if needed.
typedef ApplyThemeSideEffect = Future<void> Function(WidgetRef ref);
final applyThemeSideEffectProvider =
    Provider<ApplyThemeSideEffect>((ref) => (ref) async {});

/// All themes (built-in + custom), parsed.
final allThemesProvider = StreamProvider<List<ParsedTheme>>((ref) {
  return ref.watch(themeRepositoryProvider).watchAll().map(
        (rows) => rows
            .map((r) => ParsedTheme(row: r, schema: _parse(r)))
            .toList(),
      );
});

/// The currently active parsed theme (falls back to the first theme).
final activeThemeProvider = Provider<ParsedTheme?>((ref) {
  final id = ref.watch(activeThemeIdProvider);
  final themes = ref.watch(allThemesProvider).valueOrNull;
  if (themes == null || themes.isEmpty) return null;
  if (id != null) {
    final match = themes.where((t) => t.row.id == id).firstOrNull;
    if (match != null) return match;
  }
  return themes.first;
});

/// Applies a theme by id: persists it (via [persistActiveThemeIdProvider])
/// and runs the host app's optional side effect.
Future<void> applyTheme(WidgetRef ref, int themeId) async {
  await ref.read(persistActiveThemeIdProvider)(ref, themeId);
  await ref.read(applyThemeSideEffectProvider)(ref);
}
