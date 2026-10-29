import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

/// "I've read the privacy notice" checkbox with a tappable summary
/// (spec §8; the full notice arrives with Task 40).
class PrivacyNoticeCheck extends StatelessWidget {
  const new({
    required this.accepted,
    required this.onChanged,
    this.showError = false,
    super.key,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(value: accepted, onChanged: (v) => onChanged(v ?? false)),
            Expanded(
              child: Wrap(
                children: [
                  Text('I’ve read the ', style: text.bodyMedium),
                  GestureDetector(
                    onTap: () => _showSummary(context),
                    child: Text(
                      'privacy notice',
                      style: text.bodyMedium?.copyWith(
                        color: RoamioColors.cobalt,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Please read and accept the privacy notice.',
              style: text.bodySmall?.copyWith(color: RoamioColors.coral),
            ),
          ),
      ],
    );
  }

  void _showSummary(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Text(
          'What Roamio collects and why\n\n'
          '• Your name, email and date of birth, to run your account and '
          'keep under-18s safe.\n'
          '• Trips, tabs, receipts and photos you add, to split costs with '
          'your squad.\n'
          '• Your location, only if you switch it on, to tag a tab.\n\n'
          'Your data is stored in India (Mumbai). You can download it, '
          'correct it, delete your account or withdraw any permission from '
          'the You tab at any time.',
        ),
      ),
    ),
  );
}
