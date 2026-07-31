import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A default backup file name: `<prefix><timestamp>.json`.
String backupFileName(DateTime at, {required String prefix}) {
  final stamp =
      at.toIso8601String().replaceAll(RegExp('[^0-9]'), '').substring(0, 14);
  return '$prefix$stamp.json';
}

/// Writes [doc] to a temp file, then hands it to [MediaStore] to place
/// directly at the root of the public Downloads folder under [fileName] —
/// no share sheet, no subfolder. Safe to call from a background isolate.
///
/// `media_store_plus` is Android-only (it wraps Android's scoped-storage
/// MediaStore API), so on other platforms — Windows desktop, which has no
/// such restriction — [writeBackupFileDirect] writes straight to the real
/// Downloads folder instead.
Future<void> saveBackupDocToDownloads(
  Map<String, dynamic> doc,
  String fileName, {
  required String mediaStoreAppFolder,
}) async {
  if (Platform.isWindows) {
    final dir = await getDownloadsDirectory();
    if (dir == null) {
      throw StateError('No Downloads directory available on this platform.');
    }
    await writeBackupFileDirect(File(p.join(dir.path, fileName)), doc);
    return;
  }

  final tempDir = await getTemporaryDirectory();
  final tempFile = File(p.join(tempDir.path, fileName));
  await tempFile.writeAsString(jsonEncode(doc));
  await MediaStore.ensureInitialized();
  MediaStore.appFolder = mediaStoreAppFolder;
  await MediaStore().saveFile(
    tempFilePath: tempFile.path,
    dirType: DirType.download,
    dirName: DirName.download,
    relativePath: FilePath.root,
  );
  if (await tempFile.exists()) {
    await tempFile.delete();
  }
}

/// Writes [doc] straight to [file] — no scoped-storage ceremony needed on
/// desktop. Exposed (not just an internal helper) so it's directly testable
/// against a real temp directory without needing to mock `Platform.isWindows`.
@visibleForTesting
Future<void> writeBackupFileDirect(
  File file,
  Map<String, dynamic> doc,
) async {
  await file.writeAsString(jsonEncode(doc));
}
