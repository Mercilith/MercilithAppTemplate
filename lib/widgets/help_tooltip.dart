import 'package:flutter/material.dart';

/// A small "?" affordance that explains a nearby feature on tap. A
/// tap-to-open dialog is more discoverable on touch than a hover tooltip.
class HelpTooltip extends StatelessWidget {
  const HelpTooltip({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline, size: 18),
      visualDensity: VisualDensity.compact,
      tooltip: 'Help',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
