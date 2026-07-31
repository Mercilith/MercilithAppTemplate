import 'package:flutter/material.dart';

/// A compact palette of ARGB colors, useful for categorizing/tagging entities.
const List<Color> kSwatchPalette = [
  Color(0xFFEF5350), // red
  Color(0xFFEC407A), // pink
  Color(0xFFAB47BC), // purple
  Color(0xFF7E57C2), // deep purple
  Color(0xFF5C6BC0), // indigo
  Color(0xFF42A5F5), // blue
  Color(0xFF29B6F6), // light blue
  Color(0xFF26C6DA), // cyan
  Color(0xFF26A69A), // teal
  Color(0xFF66BB6A), // green
  Color(0xFF9CCC65), // light green
  Color(0xFFD4E157), // lime
  Color(0xFFFFCA28), // amber
  Color(0xFFFFA726), // orange
  Color(0xFFFF7043), // deep orange
  Color(0xFF8D6E63), // brown
  Color(0xFF78909C), // blue grey
];

/// A wrap of selectable color swatches. [selected] is an ARGB int or null.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _swatch(
          context,
          color: null,
          isSelected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final c in kSwatchPalette)
          _swatch(
            context,
            color: c,
            isSelected: selected == _argb(c),
            onTap: () => onSelected(_argb(c)),
          ),
      ],
    );
  }

  Widget _swatch(
    BuildContext context, {
    required Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final border = isSelected
        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
        : Border.all(color: Theme.of(context).dividerColor);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: border,
        ),
        child: color == null
            ? Icon(Icons.block, size: 18, color: Theme.of(context).hintColor)
            : (isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null),
      ),
    );
  }

  static int _argb(Color c) =>
      (c.a * 255).round() << 24 |
      (c.r * 255).round() << 16 |
      (c.g * 255).round() << 8 |
      (c.b * 255).round();
}

/// Renders an optional ARGB [colorValue] as a small dot; falls back to a
/// neutral outline when null.
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.colorValue, this.size = 14});

  final int? colorValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = colorValue != null ? Color(colorValue!) : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c ?? Colors.transparent,
        shape: BoxShape.circle,
        border: c == null
            ? Border.all(color: Theme.of(context).hintColor)
            : null,
      ),
    );
  }
}
