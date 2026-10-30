import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/tabs/data/tab_notice_service.dart';

/// Approval cards on Home (spec UC-21a): "2 tabs to approve" per adventure
/// for admins, and "Your tab was rejected" for its creator.
class TabNoticeCards extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(tabNoticesProvider).value ?? const [];
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final adventures = <String, Adventure>{
      for (final a
          in ref.watch(myAdventuresProvider).value ?? const <Adventure>[])
        a.id: a,
    };
    // Waiting cards only for squads the person still leads.
    final waiting = <String, int>{};
    final rejected = <TabNotice>[];
    for (final n in notices) {
      final adventure = adventures[n.adventureId];
      if (adventure == null) continue;
      if (n.kind == TabNoticeKind.rejected) {
        rejected.add(n);
      } else if (adventure.isLead(myUid)) {
        waiting.update(n.adventureId, (c) => c + 1, ifAbsent: () => 1);
      }
    }
    if (waiting.isEmpty && rejected.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: id, value: count) in waiting.entries)
          _NoticeCard(
            title: count == 1 ? '1 tab to approve' : '$count tabs to approve',
            subtitle: '🎒 ${adventures[id]!.name}',
            action: 'See tabs',
            onOpen: () => context.push('/adventures/$id'),
          ),
        for (final n in rejected)
          _NoticeCard(
            title: 'Your tab was rejected',
            subtitle: [
              if (n.description.isNotEmpty) n.description,
              '🎒 ${adventures[n.adventureId]!.name}',
            ].join(' · '),
            action: 'See tab',
            onOpen: () =>
                context.push('/adventures/${n.adventureId}/tabs/${n.tabId}'),
            onDismiss: () => ref.read(tabNoticeServiceProvider).dismiss(n.id),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onOpen,
    this.onDismiss,
  });

  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onOpen;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  Text(
                    subtitle,
                    style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onOpen, child: Text(action)),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss rejected tab',
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
