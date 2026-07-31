import 'package:flutter/material.dart';

import 'color_swatch_picker.dart';

/// Result of the name+color editor.
class NameColorResult {
  const NameColorResult({required this.name, required this.color});
  final String name;
  final int? color;
}

/// Shows a dialog to create/edit a named, optionally-colored entity
/// (e.g. a category, tag, or project).
Future<NameColorResult?> showNameColorDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  int? initialColor,
  String hint = 'Name',
}) {
  return showDialog<NameColorResult>(
    context: context,
    builder: (_) => _NameColorDialog(
      title: title,
      initialName: initialName,
      initialColor: initialColor,
      hint: hint,
    ),
  );
}

class _NameColorDialog extends StatefulWidget {
  const _NameColorDialog({
    required this.title,
    required this.initialName,
    required this.initialColor,
    required this.hint,
  });

  final String title;
  final String initialName;
  final int? initialColor;
  final String hint;

  @override
  State<_NameColorDialog> createState() => _NameColorDialogState();
}

class _NameColorDialogState extends State<_NameColorDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  late int? _color = widget.initialColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: widget.hint),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            const Text('Color'),
            const SizedBox(height: 8),
            ColorSwatchPicker(
              selected: _color,
              onSelected: (c) => setState(() => _color = c),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(NameColorResult(name: name, color: _color));
  }
}
