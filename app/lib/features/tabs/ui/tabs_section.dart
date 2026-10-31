import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/splits/data/settlement_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/sync/sync_banner.dart';
import 'package:roamio/features/sync/sync_controller.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';
import 'package:roamio/features/tabs/domain/tab_approval.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

/// Display names for everyone on an adventure's tabs and transfers: its
/// members, its pals (removed ones too), and people who have left or deleted
/// their account
/// ("Deleted user").
Map<String, String> squadLabels(WidgetRef ref, Adventure adventure) => {
  for (final MapEntry(:key, :value) in squadPeople(ref, adventure).entries)
    key: value.name,
};

/// Everyone who can appear on an adventure, with their pictures: see
/// [squadLabels]. Someone still being looked up isn't in it yet.
Map<String, SquadPerson> squadPeople(WidgetRef ref, Adventure adventure) {
  final members =
      ref.watch(squadPeopleProvider(adventure.memberUids.join(','))).value ??
      const <String, SquadPerson>{};
  final pals = ref.watch(palsProvider(adventure.id)).value ?? const <Pal>[];
  // Removed pals stay on their old tabs, with their nickname and picture.
  final removed =
      ref.watch(removedPalsProvider(adventure.id)).value ?? const <Pal>[];
  final known = {
    ...adventure.memberUids,
    for (final p in [...pals, ...removed]) p.id,
  };
  final tabs = ref.watch(tabsProvider(adventure.id)).value ?? const [];
  final transfers =
      ref.watch(settlementsProvider(adventure.id)).value ?? const [];
  // Looked up apart from the members, so the members don't reload.
  final others = {
    for (final t in tabs) ...[
      ...t.split.participants,
      for (final p in t.split.payers) p.payer,
    ],
    for (final s in transfers) ...[s.from, s.to],
  }.difference(known).toList()..sort();
  final otherPeople = others.isEmpty
      ? const <String, SquadPerson>{}
      : ref.watch(squadPeopleProvider(others.join(','))).value ??
            const <String, SquadPerson>{};
  return {
    ...otherPeople,
    ...members,
    for (final p in [...removed, ...pals])
      p.id: SquadPerson(name: p.nickname, characterId: p.characterId),
  };
}

/// Formats [money] with its currency's symbol when one is known.
String formatWithSymbol(WidgetRef ref, Money money) => formatMoney(
  money,
  symbol: ref.watch(countriesProvider).value?.symbolFor(money.currency),
);

/// The adventure's tabs, grouped by day, newest first; each row shows the
/// viewer's own share (spec UC-23). Tapping opens the tab.
class TabsSection extends ConsumerWidget {
  const new({required this.adventure, required this.myUid, super.key});

  final Adventure adventure;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final slate = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    final tabs = ref.watch(tabsProvider(adventure.id));
    final today = ref.watch(todayProvider);
    final open = adventure.tabsOpenOn(today);
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tabs', style: text.headlineSmall),
        if (!open)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Tabs closed 7 days after the trip ended.',
              style: slate,
            ),
          ),
        const SizedBox(height: 8),
        ...tabs.when(
          loading: () => [const LinearProgressIndicator()],
          error: (_, _) => [Text('We couldn’t load the tabs.', style: slate)],
          data: (list) => list.isEmpty
              ? [Text('No tabs yet. Add the first one.', style: slate)]
              : [
                  for (final group in groupByDay(list)) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dayLabel(group.day, today),
                            style: text.labelLarge,
                          ),
                        ),
                        Text(
                          group.tabs.length == 1
                              ? '1 tab'
                              : '${group.tabs.length} tabs',
                          style: text.labelMedium?.copyWith(
                            color: RoamioColors.slate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final t in group.tabs)
                      _TabRow(
                        tab: t,
                        category: categories[t.category],
                        myUid: myUid,
                        adventure: adventure,
                        onTap: () => context.push(
                          '/adventures/${adventure.id}/tabs/${t.id}',
                        ),
                      ),
                  ],
                ],
        ),
      ],
    );
  }
}

class _TabRow extends ConsumerWidget {
  const new({
    required this.tab,
    required this.category,
    required this.myUid,
    required this.adventure,
    required this.onTap,
  });

  final Adventure adventure;
  final TabEntry tab;
  final Category? category;
  final String myUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final slate = text.bodySmall?.copyWith(color: RoamioColors.slate);
    final sharing = tab.split.participants.contains(myUid);
    final share = formatWithSymbol(ref, tab.shareOf(myUid));
    final methods = tab.split.payers.map((p) => p.method).toSet();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: RoamioColors.hairline,
                    child: Text(
                      category?.emoji ?? '🧾',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RowLine(
                          start: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  category?.name ?? 'Tab',
                                  style: text.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tab.memories.isNotEmpty) const Text(' 📷'),
                              if (tab.location != null) const Text(' 📍'),
                            ],
                          ),
                          end: Text(
                            formatWithSymbol(ref, tab.amount),
                            style: text.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _RowLine(
                          start: Text(
                            tab.description,
                            style: slate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          end: Text(
                            sharing ? 'Your share $share' : 'Not in it',
                            style: text.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // The start of this line is for the pictures of the
                        // people sharing (Task 54).
                        Row(
                          children: [
                            const Spacer(),
                            Text(
                              methods.map((m) => m.emoji).join(),
                              semanticsLabel: paidWithLabel(methods),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (tab.status == TabStatus.personal)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    personalLabel,
                    style: text.labelMedium?.copyWith(
                      color: RoamioColors.slate,
                    ),
                  ),
                ),
              if (tab.status == TabStatus.waiting)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    waitingLabel,
                    style: text.labelMedium?.copyWith(
                      color: RoamioColors.coralText,
                    ),
                  ),
                ),
              if (tab.status == TabStatus.rejected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    switch (tab.rejectReason) {
                      final reason? => '$rejectedLabel: $reason',
                      null => rejectedLabel,
                    },
                    style: text.labelMedium?.copyWith(
                      color: RoamioColors.coralText,
                    ),
                  ),
                ),
              if (tab.status == TabStatus.rejected &&
                  tab.createdBy == myUid &&
                  adventure.tabsOpenOn(ref.watch(todayProvider)))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => context.push(
                      '/adventures/${adventure.id}/tabs/${tab.id}/edit',
                    ),
                    child: const Text('Edit and resubmit'),
                  ),
                ),
              if (canDecideTab(adventure, tab, myUid))
                _DecideButtons(adventure: adventure, tab: tab),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of a tab's row: [start] gets what [end] leaves. [end] is an amount,
/// so it shrinks to fit a small phone rather than being cut off.
class _RowLine extends StatelessWidget {
  const new({required this.start, required this.end});

  final Widget start;
  final Widget end;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        Expanded(child: start),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.7),
          child: FittedBox(fit: BoxFit.scaleDown, child: end),
        ),
      ],
    ),
  );
}

/// Approve and Reject on a waiting tab's row (spec UC-21a). Plain buttons, so
/// the page keeps its one primary button.
class _DecideButtons extends ConsumerWidget {
  const new({required this.adventure, required this.tab});

  final Adventure adventure;
  final TabEntry tab;

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _RejectDialog(),
      );
      if (reason == null) return;
    }
    try {
      await ref
          .read(tabServiceProvider)
          .decideTab(adventure.id, tab.id, approve: approve, reason: reason);
    } on TabAlreadyDecided {
      if (context.mounted) showAuthMessage(context, alreadyDecidedMessage);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);
    const small = Size(0, 40);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: small),
                  onPressed: offline
                      ? null
                      : () => _decide(context, ref, approve: true),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: small),
                  onPressed: offline
                      ? null
                      : () => _decide(context, ref, approve: false),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
          if (offline) const NeedsConnectionNote(),
        ],
      ),
    );
  }
}

/// Confirms a rejection and takes an optional reason. Returns the reason,
/// empty if none, or null when cancelled.
class _RejectDialog extends StatefulWidget {
  const new();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reject this tab?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('It won’t count towards anyone’s balance.'),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _reason.text.trim()),
        child: const Text('Reject'),
      ),
    ],
  );
}
