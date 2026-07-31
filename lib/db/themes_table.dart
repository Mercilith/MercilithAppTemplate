import 'package:drift/drift.dart';

import 'theme_kind.dart';

/// A color theme. Built-ins are seeded rows so export/import and
/// "duplicate & customize" work uniformly through one table.
///
/// [schemeJson] is an app's open, documented theme JSON (see
/// docs/theme-schema.md) — a versioned map of Material color roles to ARGB
/// values plus the theme's brightness.
///
/// This is a **copyable template**, not an importable module — it is
/// deliberately NOT exported from this package's barrel file. `drift_dev`'s
/// table-discovery builder only scans files within a package that itself
/// declares `drift_dev` as a dependency, so a `Table` subclass declared here
/// is never seen by a consuming app's own `build_runner build`; see this
/// repo's CLAUDE.md, "The Drift cross-package pattern," for the full
/// explanation (confirmed by direct testing, not assumption). Copy this
/// class into your app's own `lib/data/db/tables/` and add it to that app's
/// `@DriftDatabase(tables: [..., Themes])` list — only `ThemeKind` (a plain
/// enum) is a genuine shared import.
@DataClassName('ThemeRow')
class Themes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get kind => intEnum<ThemeKind>()();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();

  /// Stable identity of a built-in theme, independent of its display name.
  ///
  /// Null for custom themes. A unique index on this column (created by your
  /// app, since index creation is app-specific migration code) is what keeps
  /// seeding idempotent when multiple isolates open the database file at
  /// once: SQLite treats NULLs as distinct in a unique index, so custom
  /// themes are unconstrained while a losing racer's built-in inserts are
  /// dropped by `InsertMode.insertOrIgnore` instead of doubling the gallery.
  TextColumn get builtinKey => text().nullable()();
  TextColumn get schemeJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
