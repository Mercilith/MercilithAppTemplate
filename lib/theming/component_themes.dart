import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// Applies the shared component-styling layer on top of a color/brightness
/// [ThemeData] built from a [ThemeSchema] (see `theme_schema.dart`).
///
/// [ThemeSchema.toThemeData] only knows about colors — this is where the
/// actual "modern app" look (rounded cards/dialogs/snackbars, a real page
/// transition instead of the raw platform default, ...) lives, so every
/// consuming app gets it for free just by going through [ThemedMaterialApp]
/// and every future app gets the same look without copy-pasting it.
ThemeData applyComponentThemes(ThemeData base) {
  final scheme = base.colorScheme;
  final roundedSm = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.sm),
  );
  final roundedMd = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
  );
  final roundedLg = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.lg),
  );

  return base.copyWith(
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      shape: roundedMd,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerHigh,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: base.dialogTheme.copyWith(shape: roundedLg),
    snackBarTheme: base.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
      shape: roundedSm,
    ),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      shape: roundedMd,
    ),
    listTileTheme: base.listTileTheme.copyWith(
      shape: roundedMd,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
      },
    ),
  );
}
