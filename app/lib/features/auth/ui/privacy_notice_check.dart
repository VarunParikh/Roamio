import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

/// "I've read the privacy notice" checkbox with a tappable summary
/// (spec §8).
class PrivacyNoticeCheck extends StatelessWidget {
  const new({
    required this.accepted,
    required this.onChanged,
    this.showError = false,
    this.adultDeclaration = false,
    this.onDark = false,
    super.key,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final bool showError;

  /// The pilot asks no birth date: the tick also says "I'm 18 or older".
  final bool adultDeclaration;

  /// Sits on a dark photo (the first page), so the words are white.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final words = onDark ? RoamioColors.surface : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: accepted,
              onChanged: (v) => onChanged(v ?? false),
              side: onDark
                  ? const BorderSide(color: RoamioColors.surface, width: 2)
                  : null,
            ),
            Expanded(
              child: Wrap(
                children: [
                  Text(
                    adultDeclaration
                        ? 'I’m 18 or older and I’ve read the '
                        : 'I’ve read the ',
                    style: text.bodyMedium?.copyWith(color: words),
                  ),
                  GestureDetector(
                    onTap: () => _showSummary(context),
                    child: Text(
                      'privacy notice',
                      style: text.bodyMedium?.copyWith(
                        color: words ?? RoamioColors.cobalt,
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
              adultDeclaration
                  ? 'Please confirm you’re 18 or older and accept the privacy '
                        'notice.'
                  : 'Please read and accept the privacy notice.',
              style: text.bodySmall?.copyWith(
                color: onDark
                    ? RoamioColors.chartreuse
                    : RoamioColors.coralText,
              ),
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
          '• Your name and email, to run your account.\n'
          '• Trips and tabs you add, to split costs with your squad. You '
          'can’t upload pictures during the pilot, and Scan bill reads on '
          'your phone and keeps nothing.\n'
          '• Your location, only if you switch it on, to tag a tab.\n\n'
          'Your data is stored in India (Mumbai). You can download it, '
          'correct it, delete your account or withdraw any permission from '
          'the You tab at any time.',
        ),
      ),
    ),
  );
}
