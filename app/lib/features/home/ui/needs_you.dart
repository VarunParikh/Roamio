import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/budget/ui/budget_alerts.dart';
import 'package:roamio/features/invites/ui/invites_on_home.dart';
import 'package:roamio/features/notifications/ui/notification_prompt.dart';
import 'package:roamio/features/profile/ui/character_prompt.dart';
import 'package:roamio/features/squad/ui/join_cards.dart';
import 'package:roamio/features/tabs/ui/tab_notice_cards.dart';

/// Needs you (spec UC-5): the top 2 cards, then See all, always in this order:
/// tabs to approve, invites, join cards, budget alerts, character prompt,
/// notification prompt. Shows nothing when nothing needs you.
class NeedsYou extends ConsumerStatefulWidget {
  const new({this.withInvites = true, super.key});

  /// Off when invites already sit above the image card (spec UC-6).
  final bool withInvites;

  @override
  ConsumerState<NeedsYou> createState() => _NeedsYouState();
}

const _collapsedCards = 2;

class _NeedsYouState extends ConsumerState<NeedsYou> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...tabNoticeItems(context, ref),
      if (widget.withInvites) ...inviteItems(ref),
      ...joinCardItems(ref),
      ...budgetAlertItems(context, ref),
      if (characterPromptNeeded(ref)) const CharacterPrompt(key: ValueKey('c')),
      if (notificationPromptNeeded(ref))
        const NotificationPrompt(key: ValueKey('n')),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Needs you',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (items.length > _collapsedCards)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => setState(() => _all = !_all),
                  child: Text(_all ? 'Show fewer' : 'See all'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            key: const ValueKey('needs-you-items'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: _all ? items : items.take(_collapsedCards).toList(),
          ),
        ],
      ),
    );
  }
}
