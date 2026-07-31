import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a dialog to pick an opaque color via RGB sliders + hex entry, with a
/// quick palette. Returns the chosen [Color], or null if cancelled.
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required Color initial,
  String title = 'Pick a color',
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial, title: title),
  );
}

const List<Color> _quickPalette = [
  Color(0xFFEF5350), Color(0xFFEC407A), Color(0xFFAB47BC), Color(0xFF7E57C2),
  Color(0xFF5C6BC0), Color(0xFF42A5F5), Color(0xFF26C6DA), Color(0xFF26A69A),
  Color(0xFF66BB6A), Color(0xFF9CCC65), Color(0xFFFFCA28), Color(0xFFFFA726),
  Color(0xFFFF7043), Color(0xFF8D6E63), Color(0xFF000000), Color(0xFF616161),
  Color(0xFFBDBDBD), Color(0xFFFFFFFF),
];

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title});
  final Color initial;
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late int _r = (widget.initial.r * 255).round();
  late int _g = (widget.initial.g * 255).round();
  late int _b = (widget.initial.b * 255).round();
  late final TextEditingController _hexController =
      TextEditingController(text: _hex());

  Color get _color => Color.fromARGB(255, _r, _g, _b);

  String _hex() =>
      '${_r.toRadixString(16).padLeft(2, '0')}${_g.toRadixString(16).padLeft(2, '0')}${_b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  void _syncHex() => _hexController.text = _hex();

  void _applyHex(String text) {
    var s = text.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      if (v != null) {
        setState(() {
          _r = (v >> 16) & 0xff;
          _g = (v >> 8) & 0xff;
          _b = v & 0xff;
        });
      }
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
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
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 12),
            _channel('R', _r, Colors.red, (v) {
              setState(() => _r = v);
              _syncHex();
            }),
            _channel('G', _g, Colors.green, (v) {
              setState(() => _g = v);
              _syncHex();
            }),
            _channel('B', _b, Colors.blue, (v) {
              setState(() => _b = v);
              _syncHex();
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                prefixText: '#',
                labelText: 'Hex',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              ],
              onChanged: _applyHex,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _quickPalette)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _r = (c.r * 255).round();
                        _g = (c.g * 255).round();
                        _b = (c.b * 255).round();
                      });
                      _syncHex();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                    ),
                  ),
              ],
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
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('Select'),
        ),
      ],
    );
  }

  Widget _channel(
      String label, int value, Color accent, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            max: 255,
            activeColor: accent,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}
