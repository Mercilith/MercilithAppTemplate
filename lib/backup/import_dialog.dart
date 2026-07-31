import 'package:flutter/material.dart';

import 'backup_service.dart';

/// Prompts the user to choose how an imported backup should reconcile with
/// their current data. Always asks — never assumes a default — since merge
/// vs. overwrite is a meaningfully destructive choice.
Future<ImportMode?> askImportMode(BuildContext context) {
  return showDialog<ImportMode>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Import backup'),
      content: const Text(
        'How should this backup be applied to your current data?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ImportMode.merge),
          child: const Text('Merge'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ImportMode.overwrite),
          child: const Text('Overwrite'),
        ),
      ],
    ),
  );
}
