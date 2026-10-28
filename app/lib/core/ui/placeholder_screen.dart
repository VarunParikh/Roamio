import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

/// Temporary body for tabs whose features land in later tasks.
class PlaceholderScreen extends StatelessWidget {
  const new({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.displayLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
