import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/theme_kind.dart';
import '../../db/theme_repository.dart';
import '../../design/design_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/staggered_fade_in.dart';
import '../providers/theme_providers.dart';
import '../theme_io.dart';
import '../theme_schema.dart';
import 'theme_editor_screen.dart';

/// Browse, apply, create, import, and manage themes.
class ThemeGalleryScreen extends ConsumerWidget {
  const ThemeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(allThemesProvider);
    final active = ref.watch(activeThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Themes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import theme',
            onPressed: () => _import(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNew(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Custom'),
      ),
      body: themesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (themes) {
          final groups = <ThemeKind, List<ParsedTheme>>{};
          for (final t in themes) {
            groups.putIfAbsent(t.row.kind, () => []).add(t);
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: staggerFadeIn([
              for (final entry in _ordered(groups)) ...[
                _SectionHeader(_kindLabel(entry.key)),
                for (final t in entry.value)
                  _ThemeTile(
                    parsed: t,
                    isActive: active?.row.id == t.row.id,
                    onApply: () => applyTheme(ref, t.row.id),
                    onAction: (a) => _handleAction(context, ref, t, a),
                  ),
              ],
            ]),
          );
        },
      ),
    );
  }

  List<MapEntry<ThemeKind, List<ParsedTheme>>> _ordered(
      Map<ThemeKind, List<ParsedTheme>> groups) {
    const order = [
      ThemeKind.builtInLight,
      ThemeKind.builtInDark,
      ThemeKind.builtInMonochrome,
      ThemeKind.custom,
    ];
    return [
      for (final k in order)
        if (groups[k] != null) MapEntry(k, groups[k]!),
    ];
  }

  String _kindLabel(ThemeKind k) => switch (k) {
        ThemeKind.builtInLight => 'Light',
        ThemeKind.builtInDark => 'Dark',
        ThemeKind.builtInMonochrome => 'Monochrome',
        ThemeKind.custom => 'Custom',
      };

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    ParsedTheme t,
    _ThemeAction action,
  ) async {
    switch (action) {
      case _ThemeAction.edit:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              ThemeEditorScreen(initial: t.schema, existingThemeId: t.row.id),
        ));
      case _ThemeAction.duplicate:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ThemeEditorScreen(
            initial: t.schema.copyWith(name: '${t.schema.name} copy'),
          ),
        ));
      case _ThemeAction.export:
        await exportThemeFile(t.schema);
      case _ThemeAction.delete:
        await _delete(context, ref, t);
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, ParsedTheme t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete “${t.schema.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final active = ref.read(activeThemeProvider);
    final repo = ref.read(themeRepositoryProvider);
    await repo.delete(t.row.id);
    // If the active theme was deleted, fall back to the first remaining one.
    if (active?.row.id == t.row.id) {
      final remaining = await repo.all();
      if (remaining.isNotEmpty) {
        await applyTheme(ref, remaining.first.id);
      }
    }
  }

  Future<void> _createNew(BuildContext context, WidgetRef ref) async {
    final base = ThemeSchema.fromColorScheme(
      'My theme',
      ColorScheme.fromSeed(seedColor: const Color(0xFF5C6BC0)),
    );
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ThemeEditorScreen(initial: base),
    ));
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final result = await importThemeFile();
    if (result.isCancelled) return;
    if (!result.isSuccess) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${result.error}')),
        );
      }
      return;
    }
    // Imported themes are always added as new custom themes (never overwrite
    // a built-in).
    final schema = result.schema!;
    final id = await ref.read(themeRepositoryProvider).create(
          NewTheme(
            name: schema.name,
            kind: ThemeKind.custom,
            schemeJson: jsonEncode(schema.toJson()),
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported “${schema.name}”'),
          action: SnackBarAction(
            label: 'Apply',
            onPressed: () => applyTheme(ref, id),
          ),
        ),
      );
    }
  }
}

enum _ThemeAction { edit, duplicate, export, delete }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.parsed,
    required this.isActive,
    required this.onApply,
    required this.onAction,
  });

  final ParsedTheme parsed;
  final bool isActive;
  final VoidCallback onApply;
  final ValueChanged<_ThemeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final s = parsed.schema;
    final isCustom = parsed.row.kind == ThemeKind.custom;
    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      onTap: onApply,
      child: Row(
        children: [
          _Swatches(schema: s),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  s.brightness == Brightness.dark ? 'Dark' : 'Light',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (isActive)
            Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.primary),
          PopupMenuButton<_ThemeAction>(
            onSelected: onAction,
            itemBuilder: (_) => [
              if (isCustom)
                const PopupMenuItem(
                    value: _ThemeAction.edit, child: Text('Edit')),
              const PopupMenuItem(
                  value: _ThemeAction.duplicate, child: Text('Duplicate')),
              const PopupMenuItem(
                  value: _ThemeAction.export, child: Text('Export')),
              if (isCustom)
                const PopupMenuItem(
                    value: _ThemeAction.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.schema});
  final ThemeSchema schema;

  @override
  Widget build(BuildContext context) {
    final colors = [
      schema.role('primary'),
      schema.role('secondary'),
      schema.role('tertiary'),
      schema.role('surface'),
    ];
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final c in colors) Expanded(child: Container(color: c)),
        ],
      ),
    );
  }
}
