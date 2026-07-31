# Working Instructions for Claude

## What this repo is

A Flutter *library package*, not an app. It exists purely to share code
across Mercilith's apps (TaskApp today, others later) so theming, backups,
and a few other cross-cutting concerns stay consistent without being
copy-pasted per app. There is no shared runtime state, no cross-app sync,
and no server — every consuming app keeps its own local database; this repo
only ships the *code* that database and UI layer are built from.

Consuming apps depend on this via a git dependency in their `pubspec.yaml`
(see README.md). Because it's a dependency, not a template scaffolded once
and forgotten, changes here should be made with the assumption that at
least one other app is already relying on the current API shape — avoid
breaking changes without checking who else might be affected.

## Commit discipline

Same convention as this org's other repos: commit at every natural stopping
point, and **delegate every commit to the `commit-writer` subagent** rather
than writing the message or running `git commit` yourself — this applies
from the very first commit in this repo, since `.claude/agents/commit-writer.md`
is checked in from day one. Don't wait for explicit permission to commit;
do pause before pushing, force-pushing, or rewriting history.

## Architecture

```
lib/
  mercilith_app_template.dart   # barrel export
  theming/
    theme_schema.dart           # ThemeSchema — pure Dart JSON<->ColorScheme, no DB coupling
    builtin_themes.dart         # the 12 built-in theme definitions
    theme_io.dart                # file export/import (file_picker/share_plus)
    themed_material_app.dart    # MaterialApp wrapper: one active theme drives light/dark
    screens/                    # theme gallery + editor UI
    providers/                  # Riverpod theme_providers, parameterized (see below)
  db/
    theme_kind.dart             # ThemeKind enum (builtInLight/Dark/Monochrome/custom)
    themes_table.dart           # plain Drift Table — see "Drift cross-package pattern"
    theme_repository.dart       # abstract ThemeRepository + plain ThemeRow/NewTheme
    connection_hardening.dart   # prepareConnection/openDatabaseFile/safeAddColumn/busyTimeout
  backup/
    backup_service.dart         # generic BackupService/TableSpec/ImportMode
    backup_file_io.dart         # saveBackupDocToDownloads/writeBackupFileDirect
    import_dialog.dart          # askImportMode
  widgets/                      # help_tooltip, centered_form_width, color pickers, name+color dialog
  navigation/
    adaptive_nav_scaffold.dart  # responsive NavigationBar/NavigationRail shell
  notifications/
    notification_service.dart  # parameterized Android/Windows notification wrapper
    fire_times.dart             # pure fire-time computation
    notification_repeat_mode.dart
```

## The Drift cross-package pattern (read this before touching `db/`)

This package ships **plain Drift `Table` classes** (like `Themes`) but
**never `@DriftAccessor`/`@DriftDatabase`-annotated classes**. This is a
hard constraint, not a stylistic choice — here's why.

`drift_dev` (like `json_serializable`, `freezed`, and every other
`build_runner`/`source_gen`-based generator) only ever generates code for
annotations found in the *root package's own* `lib/` — the package that
actually invokes `build_runner build`. A builder never reaches into an
imported package's `lib/` to write a `.g.dart` file there. That's why:

- A **plain `Table` subclass** (no annotation of its own, just getters) can
  be imported into a consuming app's `@DriftDatabase(tables: [..., Themes])`
  list, and it works perfectly — when `build_runner` runs *inside the
  consuming app*, `drift_dev` resolves `Themes` via the Dart analyzer
  regardless of which package physically declared the class, and emits the
  corresponding `ThemeRow`/`ThemesCompanion` into the app's own
  `database.g.dart`.
- An **`@DriftAccessor`-annotated DAO** (e.g. a hypothetical `ThemeDao`)
  needs a generated `part` file (`_$ThemeDaoMixin`) that only the
  *consuming app's own* `build_runner` run can produce — and that mixin is
  typed against the consuming app's own `@DriftDatabase` class, which this
  package can never know about in advance. There is no way to ship a
  DAO from here that "just works" when imported.

**So**: this package ships the table + an abstract `ThemeRepository`
interface (with its own plain, hand-written `ThemeRow`/`NewTheme` data
classes — deliberately *not* named the same as Drift's generated row type
to avoid confusion, though the names do collide; import with a prefix or
`hide` in consuming code). Each consuming app writes its own small,
concrete `@DriftAccessor` DAO exactly as it always would, then adds a thin
adapter class implementing `ThemeRepository` by wrapping that DAO. The
shared theme screens/providers in this package depend only on the abstract
interface, never on any app's generated types.

**If you add another shared table in the future, follow this exact
pattern** — plain table class + abstract repository interface + let each
app supply its own DAO-backed adapter. Do not try to make a DAO itself
shareable; it will not compile in the consuming app.

## Notification background-handler constraint

`NotificationService`'s Android/Windows background action handler must be a
real top-level function annotated `@pragma('vm:entry-point')` — Dart
isolate entry points cannot be a closure or an instance method, so this
package cannot ship a fixed background handler. `NotificationService.init()`
takes an `onBackgroundResponse` callback; each consuming app defines its own
top-level wrapper function and passes it in.

## Toolchain gotchas (do not "fix" these without understanding why)

1. **No `build_runner`/`drift_dev` dev-dependency in this package, deliberately.** This package has zero `@DriftAccessor`/`@DriftDatabase` classes (see the Drift cross-package pattern above) — if you ever find yourself wanting to add one here, stop and re-read that section first; it will not work the way you expect.
2. **`ThemeRow` name collision.** This package's `db/theme_repository.dart` defines a plain `ThemeRow` data class. Every consuming app's Drift setup also generates its *own* `ThemeRow` (from the `Themes` table, in that app's `database.g.dart`). These are different types with the same name. Consuming code that needs both must import one with a prefix or `hide` clause — don't rename either to "fix" this, the collision is inherent to the design (see the Drift pattern section).
3. **No `sqlite3_flutter_libs` dependency here, deliberately.** This package only touches Drift's `Migrator`/`TableInfo`/`GeneratedColumn` abstractions and the `sqlite3.Database` type (a transitive dependency via `drift`) — it never opens a real database file. Bundling native sqlite3 binaries is an app-level concern (each app's own `sqlite3_flutter_libs` dependency); don't add it here "to be safe."
4. **Windows notifications reuse one native string for both `NotificationResponse.actionId` and `.payload`.** Unlike Android, where the action id and the notification payload travel separately, `flutter_local_notifications`'s Windows implementation surfaces a single "invoked args" string as *both* fields — tapping an action button overwrites both with that button's `arguments` string. `NotificationService`'s Windows path works around this by embedding the action id inside the payload JSON itself (`kWindowsActionKey`); consuming code must unwrap that key before treating the rest of the payload as the real notification data. If you change the payload shape, keep this embedding intact or Windows action buttons will silently lose their payload.
5. **CI/build patterns (Flutter version pin, the Windows-Developer-Mode-enable step, the debug-keystore signing pattern) are documented, not shared, here.** A Flutter *package* has no `android/`/`windows/` runner folders of its own, so none of this is literally shareable code — see `docs/templates/build.yml.example` for a copyable starting point each new app's own CI workflow should be based on, and re-derive the debug-keystore pattern per-app (never share one keystore file across apps — that's a real signing/security anti-pattern, not just inconvenient).
