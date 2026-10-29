import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

/// The one chartreuse call-to-action a screen may have (CLAUDE.md, spec §12).
/// Shows a spinner while [busy]; disabled when [onPressed] is null.
class PrimaryButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: RoamioColors.chartreuse,
        foregroundColor: RoamioColors.ink,
        disabledBackgroundColor: RoamioColors.chartreuse.withValues(
          alpha: 0.45,
        ),
        disabledForegroundColor: RoamioColors.ink.withValues(alpha: 0.6),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: RoamioColors.ink,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );
  }
}
