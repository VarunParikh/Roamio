import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/notifications/data/notification_service.dart';

/// Whether [NotificationPrompt] has anything to ask.
bool notificationPromptNeeded(WidgetRef ref) {
  final consent = ref.watch(notificationConsentProvider);
  final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
  final leadsSomething = (ref.watch(myAdventuresProvider).value ?? const [])
      .any((a) => a.isLead(myUid));
  return consent.hasValue && consent.value == null && leadsSomething;
}

/// Phones get new IDs from time to time, so someone who has notifications on
/// re-registers on each start. Always on Home, and shows nothing.
class PushIdRefresher extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PushIdRefresher> createState() => _PushIdRefresherState();
}

class _PushIdRefresherState extends ConsumerState<PushIdRefresher> {
  bool _refreshed = false;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(notificationConsentProvider).value == true && !_refreshed) {
      _refreshed = true;
      unawaited(ref.read(notificationServiceProvider).refresh());
    }
    return const SizedBox.shrink();
  }
}

/// Asks squad leads, once, whether they want a push when someone joins
/// (spec UC-14). Android's own prompt only appears after Turn on, and the
/// answer is saved as their notification consent (spec §8).
class NotificationPrompt extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NotificationPrompt> createState() => _NotificationPromptState();
}

class _NotificationPromptState extends ConsumerState<NotificationPrompt> {
  bool _busy = false;

  Future<void> _turnOn() async {
    setState(() => _busy = true);
    final on = await ref.read(notificationServiceProvider).turnOn();
    if (!mounted) return;
    setState(() => _busy = false);
    showAuthMessage(
      context,
      on
          ? 'Done. We’ll let you know when friends join.'
          : 'Notifications are off. You can allow them in settings later.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Know when friends join', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Get a notification when someone joins your squad.',
              style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _turnOn,
                    child: const Text('Turn on'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref.read(notificationServiceProvider).decline(),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
