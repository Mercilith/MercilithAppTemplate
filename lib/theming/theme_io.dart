import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'theme_schema.dart';

/// Exports a theme to a shareable `.json` file.
Future<void> exportThemeFile(ThemeSchema schema, {String? shareSubject}) async {
  final dir = await getTemporaryDirectory();
  final safeName = schema.name
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .toLowerCase();
  final file = File(p.join(dir.path, 'theme_$safeName.json'));
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(schema.toJson()),
  );
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: shareSubject ?? 'Theme: ${schema.name}',
    ),
  );
}

/// Result of an import attempt.
class ThemeImportResult {
  const ThemeImportResult.success(this.schema) : error = null;
  const ThemeImportResult.failure(this.error) : schema = null;
  const ThemeImportResult.cancelled()
      : schema = null,
        error = null;

  final ThemeSchema? schema;
  final String? error;

  bool get isSuccess => schema != null;
  bool get isCancelled => schema == null && error == null;
}

/// Prompts the user to pick a `.json` theme file and parses it.
Future<ThemeImportResult> importThemeFile() async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (picked.isEmpty) {
    return const ThemeImportResult.cancelled();
  }
  final file = picked.single;
  try {
    final content = utf8.decode(await file.readAsBytes());
    final json = jsonDecode(content);
    if (json is! Map<String, dynamic>) {
      return const ThemeImportResult.failure('Not a valid theme file.');
    }
    return ThemeImportResult.success(ThemeSchema.fromJson(json));
  } on FormatException catch (e) {
    return ThemeImportResult.failure(e.message);
  } catch (_) {
    return const ThemeImportResult.failure('Could not parse the theme file.');
  }
}
