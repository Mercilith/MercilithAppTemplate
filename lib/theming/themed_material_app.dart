import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_providers.dart';

/// A [MaterialApp] driven by a single active theme (via [activeThemeProvider])
/// rather than the OS light/dark setting — the active theme's own brightness
/// is applied to whichever of `theme`/`darkTheme` matches, with [fallbackLight]
/// used for the other slot and as the default before any theme has loaded.
class ThemedMaterialApp extends ConsumerWidget {
  const ThemedMaterialApp({
    super.key,
    required this.home,
    required this.fallbackLight,
    this.title = '',
    this.debugShowCheckedModeBanner = false,
  });

  final Widget home;
  final ThemeData fallbackLight;
  final String title;
  final bool debugShowCheckedModeBanner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeThemeProvider);
    final schema = active?.schema;

    final themeData = schema?.toThemeData() ?? fallbackLight;
    final isDark = schema?.brightness == Brightness.dark;

    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      theme: isDark ? fallbackLight : themeData,
      darkTheme: isDark ? themeData : null,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    );
  }
}
