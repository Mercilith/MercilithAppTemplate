import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

/// How long a blocked write waits for the lock before giving up. Generous
/// enough to outlast a background write, short enough that a genuinely
/// stuck lock still surfaces rather than hanging the UI forever.
const busyTimeout = Duration(seconds: 5);

/// Prepares a raw sqlite connection, in whichever isolate opened it.
///
/// Any app where multiple isolates (UI, background jobs, notification
/// actions, a home-screen widget callback, ...) open the same database file
/// needs this — concurrent access from more than one isolate is normal, not
/// exceptional:
///
///  * WAL lets readers and a writer proceed at the same time instead of
///    locking each other out.
///  * `busy_timeout` makes a blocked writer wait its turn and retry rather
///    than failing instantly with SQLITE_BUSY ("database is locked"), which
///    otherwise surfaces as a launch-time error whenever a background
///    isolate happened to be mid-write.
///
/// Both are per-connection settings (WAL also persists in the file), and
/// must be applied here rather than in a `beforeOpen` callback, so they
/// already cover Drift's own migration and open-time statements.
@pragma('vm:entry-point')
void prepareConnection(Database db) {
  // First, so anything below can wait for a lock rather than fail outright.
  db.execute('PRAGMA busy_timeout = ${busyTimeout.inMilliseconds};');
  // Switching journal mode needs a lock on the file, so only do it when the
  // mode is actually wrong — otherwise every open would contend with
  // whatever another isolate is doing. WAL persists in the file, so in
  // practice this only writes once, when the database is first created.
  final mode = db.select('PRAGMA journal_mode;').first.values.first;
  if (mode != 'wal') {
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {
      // Switching needs an exclusive lock, which another isolate creating
      // the database at the same moment may hold. Whoever wins sets it for
      // good — and WAL is an optimization, so never let this stop the app
      // opening.
    }
  }
}

/// Opens [file] the way every isolate should, with [prepareConnection]
/// applied. Exposed so tests can exercise the real connection setup against
/// a temporary file.
QueryExecutor openDatabaseFile(File file) =>
    NativeDatabase.createInBackground(file, setup: prepareConnection);

/// Runs a migration step's `addColumn` tolerantly of a second isolate
/// racing the same step.
///
/// When multiple isolates independently read `PRAGMA user_version` at open
/// time, more than one can decide to run the same upgrade step if the app
/// updated while more than one was about to open the file. SQLite
/// serializes their writes, but only the first to actually reach a given
/// `ALTER TABLE ... ADD COLUMN` succeeds — by the time the second one gets
/// the lock, the column it's about to add already exists, and it throws
/// "duplicate column name" instead of a lock error (unlike `createTable`,
/// which Drift already emits as `CREATE TABLE IF NOT EXISTS`). That's
/// additive-schema noise, not a real failure, so it's swallowed here.
Future<void> safeAddColumn(
  Migrator m,
  TableInfo table,
  GeneratedColumn column,
) async {
  try {
    await m.addColumn(table, column);
  } catch (e) {
    // NativeDatabase.createInBackground runs the connection on its own
    // isolate, so the real SqliteException arrives here wrapped in a
    // DriftRemoteException — check the message rather than the type.
    if (!e.toString().contains('duplicate column name')) rethrow;
  }
}
