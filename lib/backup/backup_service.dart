import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';

/// Backup file format version (independent of any app's DB schema version).
const int kBackupVersion = 1;

/// How an import reconciles with existing data.
enum ImportMode { merge, overwrite }

/// One table's export/restore wiring.
class TableSpec {
  TableSpec(this.name, this.table, this.fromJson, {this.skipOnMerge = false});
  final String name;
  final TableInfo table;
  final Insertable Function(Map<String, dynamic>) fromJson;

  /// Tables flagged here are left untouched on a merge import (typically a
  /// singleton settings-style table, so a merge doesn't clobber current
  /// config with whatever was in the backup).
  final bool skipOnMerge;
}

/// Exports/imports a full app dataset as a single JSON document, given the
/// list of tables to cover. Schema-agnostic: works against any
/// [GeneratedDatabase] and any [TableSpec] list a host app supplies.
class BackupService {
  BackupService(
    this.db, {
    required this.specs,
    this.onAfterOverwrite,
  });

  final GeneratedDatabase db;
  final List<TableSpec> specs;

  /// Runs (inside the same transaction as the rest of `restore()`) after an
  /// overwrite-mode restore clears and reinserts every table — use this for
  /// any app-specific "guarantee this singleton row still exists" cleanup.
  final Future<void> Function(GeneratedDatabase db)? onAfterOverwrite;

  /// Serializes the whole dataset to a backup document (no I/O).
  Future<Map<String, dynamic>> buildDocument() async {
    final tables = <String, dynamic>{};
    for (final spec in specs) {
      final rows = await db.select(spec.table).get();
      tables[spec.name] =
          rows.map((r) => (r as dynamic).toJson() as Map<String, dynamic>)
              .toList();
    }
    return {
      'backupVersion': kBackupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    };
  }

  /// Prompts the user to pick a `.json` backup file, reads and validates it
  /// (does not write). Returns the parsed doc or throws [FormatException]
  /// (with message `'cancelled'` if the user cancelled the picker).
  Future<Map<String, dynamic>> pickAndParse() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty) {
      throw const FormatException('cancelled');
    }
    final content = utf8.decode(await picked.single.readAsBytes());
    final json = jsonDecode(content);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Not a valid backup file.');
    }
    final version = json['backupVersion'];
    if (version is! int) {
      throw const FormatException('Missing backup version.');
    }
    if (version > kBackupVersion) {
      throw FormatException('Backup is from a newer app (v$version).');
    }
    if (json['tables'] is! Map) {
      throw const FormatException('Backup has no data.');
    }
    return json;
  }

  /// Restores a parsed backup document. Runs in a single transaction with
  /// deferred FK checks so insertion order doesn't matter.
  Future<void> restore(Map<String, dynamic> doc, ImportMode mode) async {
    final tables = doc['tables'] as Map<String, dynamic>;
    await db.transaction(() async {
      await db.customStatement('PRAGMA defer_foreign_keys = ON');

      if (mode == ImportMode.overwrite) {
        // Clear everything first (FK deferral covers cross-table refs).
        for (final spec in specs) {
          await db.delete(spec.table).go();
        }
      }

      final insertMode = mode == ImportMode.overwrite
          ? InsertMode.insertOrReplace
          : InsertMode.insertOrIgnore;

      for (final spec in specs) {
        if (mode == ImportMode.merge && spec.skipOnMerge) continue;
        final rows = (tables[spec.name] as List?) ?? const [];
        for (final raw in rows) {
          final row = spec.fromJson(raw as Map<String, dynamic>);
          await db.into(spec.table).insert(row, mode: insertMode);
        }
      }

      if (mode == ImportMode.overwrite && onAfterOverwrite != null) {
        await onAfterOverwrite!(db);
      }
    });
  }
}
