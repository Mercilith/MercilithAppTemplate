import 'theme_kind.dart';

/// Plain (non-Drift-generated) row shape for a theme. Deliberately named the
/// same as Drift's own generated row type for the `Themes` table — that's an
/// intentional naming collision, not an accident (see this repo's CLAUDE.md,
/// "The Drift cross-package pattern"). Import whichever you need with a
/// prefix or `hide` clause when both are in scope.
class ThemeRow {
  const ThemeRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.isBuiltin,
    this.builtinKey,
    required this.schemeJson,
    required this.createdAt,
  });

  final int id;
  final String name;
  final ThemeKind kind;
  final bool isBuiltin;
  final String? builtinKey;
  final String schemeJson;
  final DateTime createdAt;
}

/// The fields needed to insert a new theme row.
class NewTheme {
  const NewTheme({
    required this.name,
    required this.kind,
    this.isBuiltin = false,
    this.builtinKey,
    required this.schemeJson,
  });

  final String name;
  final ThemeKind kind;
  final bool isBuiltin;
  final String? builtinKey;
  final String schemeJson;
}

/// Abstract access to a theme store. The shared theme gallery/editor screens
/// and providers depend only on this interface, never on any app's concrete
/// generated Drift types — each consuming app implements it with a thin
/// adapter over its own `@DriftAccessor` DAO. See this repo's CLAUDE.md,
/// "The Drift cross-package pattern," for why the DAO itself can't be shared.
abstract class ThemeRepository {
  Stream<List<ThemeRow>> watchAll();
  Future<List<ThemeRow>> all();
  Future<ThemeRow?> getById(int id);
  Future<int> create(NewTheme entry);

  /// Inserts [entries], dropping any whose `builtinKey` already exists.
  /// Safe to call from multiple isolates opening the database at once.
  Future<void> seedBuiltIns(List<NewTheme> entries);
  Future<bool> update(ThemeRow row);
  Future<int> delete(int id);
  Future<int> count();
}
