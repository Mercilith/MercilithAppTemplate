import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/theme_kind.dart';
import '../../db/theme_repository.dart';
import '../../widgets/color_picker.dart';
import '../providers/theme_providers.dart';
import '../theme_io.dart';
import '../theme_schema.dart';

/// Creates or edits a custom theme, with a live preview.
class ThemeEditorScreen extends ConsumerStatefulWidget {
  const ThemeEditorScreen({
    super.key,
    required this.initial,
    this.existingThemeId,
  });

  /// Starting schema (a base to customize).
  final ThemeSchema initial;

  /// When set, saving updates this custom theme; otherwise a new one is added.
  final int? existingThemeId;

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  late String _name = widget.initial.name;
  late Brightness _brightness = widget.initial.brightness;
  late Map<String, int> _colors = Map.of(widget.initial.colors);
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initial.name);
  bool _showAllRoles = false;

  ThemeSchema get _schema =>
      ThemeSchema(name: _name, brightness: _brightness, colors: _colors);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = _showAllRoles ? kThemeRoles : kPrimaryEditorRoles;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingThemeId == null ? 'New theme' : 'Edit theme'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export',
            onPressed: () => exportThemeFile(_schema),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ThemePreview(schema: _schema),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _name = v),
          ),
          const SizedBox(height: 16),
          SegmentedButton<Brightness>(
            segments: const [
              ButtonSegment(
                value: Brightness.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: Brightness.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {_brightness},
            onSelectionChanged: (s) => setState(() => _brightness = s.first),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _regenerateFromSeed,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate from primary color'),
            ),
          ),
          const Divider(height: 24),
          Text('Colors', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final role in roles) _colorRow(role),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAllRoles = !_showAllRoles),
              child: Text(_showAllRoles
                  ? 'Show fewer roles'
                  : 'Show all ${kThemeRoles.length} roles'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String role) {
    final color = _colors.containsKey(role)
        ? Color(_colors[role]!)
        : _schema.role(role);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
      ),
      title: Text(role),
      subtitle: Text(
        '#${((color.a * 255).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
                '${((color.r * 255).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
                '${((color.g * 255).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
                '${((color.b * 255).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
            .toUpperCase(),
      ),
      onTap: () async {
        final picked = await showColorPickerDialog(
          context,
          initial: color,
          title: role,
        );
        if (picked != null) {
          setState(() => _colors[role] = _argb(picked));
        }
      },
    );
  }

  int _argb(Color c) =>
      ((c.a * 255).round() & 0xff) << 24 |
      ((c.r * 255).round() & 0xff) << 16 |
      ((c.g * 255).round() & 0xff) << 8 |
      ((c.b * 255).round() & 0xff);

  void _regenerateFromSeed() {
    final seed = _schema.role('primary');
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: _brightness);
    setState(() {
      _colors = ThemeSchema.fromColorScheme(_name, scheme).colors;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please name the theme.')),
      );
      return;
    }
    final schema =
        ThemeSchema(name: name, brightness: _brightness, colors: _colors);
    final repo = ref.read(themeRepositoryProvider);
    if (widget.existingThemeId != null) {
      final existing = await repo.getById(widget.existingThemeId!);
      if (existing != null) {
        await repo.update(ThemeRow(
          id: existing.id,
          name: name,
          kind: existing.kind,
          isBuiltin: existing.isBuiltin,
          builtinKey: existing.builtinKey,
          schemeJson: jsonEncode(schema.toJson()),
          createdAt: existing.createdAt,
        ));
      }
    } else {
      final id = await repo.create(
        NewTheme(
          name: name,
          kind: ThemeKind.custom,
          schemeJson: jsonEncode(schema.toJson()),
        ),
      );
      // Apply the newly created theme immediately.
      await applyTheme(ref, id);
    }
    if (mounted) Navigator.of(context).pop();
  }
}

/// A compact live preview of the theme under construction.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.schema});
  final ThemeSchema schema;

  @override
  Widget build(BuildContext context) {
    final theme = schema.toThemeData();
    final scheme = theme.colorScheme;
    return Theme(
      data: theme,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: scheme.primary,
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: Row(
                children: [
                  Icon(Icons.today, color: scheme.onPrimary),
                  const SizedBox(width: 8),
                  Text('Today',
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sample task',
                      style: TextStyle(color: scheme.onSurface, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('A preview of your theme',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton(onPressed: () {}, child: const Text('Add')),
                      OutlinedButton(
                          onPressed: () {}, child: const Text('Edit')),
                      Chip(
                        label: const Text('Tag'),
                        backgroundColor: scheme.secondaryContainer,
                        labelStyle:
                            TextStyle(color: scheme.onSecondaryContainer),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('3/5',
                            style: TextStyle(
                                color: scheme.onTertiaryContainer)),
                      ),
                      Icon(Icons.error_outline, color: scheme.error),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
