import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

/// "Name joined your squad" cards on Home for leads (spec UC-14).
class JoinCardsList extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(joinCardsProvider).value ?? const [];
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final adventures = <String, Adventure>{
      for (final a
          in ref.watch(myAdventuresProvider).value ?? const <Adventure>[])
        a.id: a,
    };
    // Only for squads the person still leads.
    final shown = [
      for (final c in cards)
        if (adventures[c.adventureId]?.isLead(myUid) ?? false) c,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in shown)
          _JoinCardView(
            card: c,
            isLeader: adventures[c.adventureId]!.leaderUid == myUid,
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _JoinCardView extends ConsumerStatefulWidget {
  const new({required this.card, required this.isLeader});

  final JoinCard card;
  final bool isLeader;

  @override
  ConsumerState<_JoinCardView> createState() => _JoinCardViewState();
}

class _JoinCardViewState extends ConsumerState<_JoinCardView> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showAuthMessage(context, done);
    } on SquadException catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final c = widget.card;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${c.memberName} from ${c.adventureName}?'),
        content: const Text(
          'They’ll leave the squad. You can invite them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _act(
      () => ref
          .read(squadServiceProvider)
          .removeMember(c.adventureId, c.memberUid),
      '${c.memberName} was removed from the squad.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final text = Theme.of(context).textTheme;
    final squad = ref.read(squadServiceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${c.memberName} joined your squad',
                    style: text.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close),
                  onPressed: _busy ? null : () => squad.dismiss(c.id),
                ),
              ],
            ),
            Text(
              '🎒 ${c.adventureName}',
              style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.isLeader) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () =>
                                  squad.makeCoLead(c.adventureId, c.memberUid),
                              '${c.memberName} is now a co-lead.',
                            ),
                      child: const Text('Make co-lead'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: _busy ? null : _remove,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
