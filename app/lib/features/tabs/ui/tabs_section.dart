import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/splits/data/settlement_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';

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
    final labels = squadLabels(ref, adventure);

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
                        labels: labels,
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
    required this.labels,
    required this.onTap,
  });

  final TabEntry tab;
  final Category? category;
  final String myUid;
  final Map<String, String> labels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final payers = tab.split.payers;
    final paidBy = payers.length > 1
        ? '${payers.length} people paid'
        : payers.single.payer == myUid
        ? 'You paid'
        : '${labels[payers.single.payer] ?? 'Someone'} paid';
    final sharing = tab.split.participants.contains(myUid);
    final name = tab.description.isEmpty
        ? category?.name ?? 'Tab'
        : tab.description;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tab.memories.isNotEmpty) const Text(' 📷'),
                        if (tab.location != null) const Text(' 📍'),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$paidBy · Total ${formatWithSymbol(ref, tab.amount)}',
                      style: text.bodySmall?.copyWith(
                        color: RoamioColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    sharing
                        ? formatWithSymbol(ref, tab.shareOf(myUid))
                        : 'Not in it',
                    style: text.titleMedium,
                  ),
                  if (sharing)
                    Text(
                      'Your share',
                      style: text.labelSmall?.copyWith(
                        color: RoamioColors.slate,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
