import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/budget/ui/budget_widget.dart';
import 'package:roamio/features/splits/data/split_report_provider.dart';
import 'package:roamio/features/splits/domain/category_shares.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/ui/split_charts.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// The expanded part of Home's adventure card (spec UC-5): budget, daily spend,
/// squad and recent activity. Only built when expanded, so tabs load then.
class HeroDetails extends ConsumerWidget {
  const new({required this.adventure, super.key});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = adventure;
    final text = Theme.of(context).textTheme;
    final started =
        a.statusOn(ref.watch(todayProvider)) != AdventureStatus.upcoming;
    void openSplit() => context.go(Routes.splitFor(a.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BudgetWidget(adventure: a),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: openSplit,
              child: const Text('See split'),
            ),
          ),
          if (started) ...[
            const Divider(color: RoamioColors.hairline),
            Row(
              children: [
                Expanded(child: Text('Daily spend', style: text.titleMedium)),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: openSplit,
                  child: const Text('View all'),
                ),
              ],
            ),
            _DailySpend(adventure: a),
            const SizedBox(height: 8),
          ],
          const Divider(color: RoamioColors.hairline),
          _SquadRow(adventure: a),
          _ActivityRow(adventure: a),
        ],
      ),
    );
  }
}

class _DailySpend extends ConsumerWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slate = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: RoamioColors.slate);
    final report = ref.watch(splitReportProvider(adventure.id));
    final r = report.value;
    if (r == null) {
      return report.hasError
          ? Text('We couldn’t load the spending.', style: slate)
          : const LinearProgressIndicator();
    }
    if (r.missingRates && r.balances.isEmpty) {
      return Text('Exchange rates aren’t available yet.', style: slate);
    }
    if (r.totalSpend == 0) return Text('No spending yet', style: slate);
    final today = ref.watch(todayProvider);
    final end = adventure.endDate.isBefore(today) ? adventure.endDate : today;
    final start = adventure.startDate;
    return DayBars(
      days: allDays({
        DateTime(start.year, start.month, start.day): 0,
        DateTime(end.year, end.month, end.day): 0,
      }),
      amountOf: (d) => r.byDay[d] ?? 0,
      dayName: (d) => dayLabel(d, today),
      moneyOf: (m) => formatWithSymbol(ref, Money(m, r.currency)),
      visibleDays: 7,
    );
  }
}

class _SquadRow extends ConsumerWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = squadWithoutTabs(ref, adventure);
    final pals = ref.watch(palsProvider(adventure.id)).value ?? const <Pal>[];
    final ids = [...adventure.memberUids, for (final p in pals) p.id];
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    return _LinkRow(
      key: const ValueKey('hero-squad'),
      label: 'Your squad, ${ids.length} people',
      onTap: () => context.push('/adventures/${adventure.id}/squad'),
      child: Row(
        children: [
          Text('Squad', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: PeoplePictures(
                ids: ids,
                people: people,
                firstUid: myUid,
                label: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(latestActivityProvider(adventure.id)).value;
    if (entry == null) return const SizedBox.shrink();
    final people = squadWithoutTabs(ref, adventure);
    final line = describeActivity(
      entry,
      myUid: ref.watch(sessionFactsProvider).value?.uid ?? '',
      who: (id) => people[id]?.name ?? 'Someone',
    );
    if (line == null) return const SizedBox.shrink();
    return _LinkRow(
      key: const ValueKey('hero-activity'),
      label: line,
      onTap: () => context.push('/adventures/${adventure.id}/activity'),
      child: Row(
        children: [
          PersonAvatar(
            uid: entry.actorUid,
            person: people[entry.actorUid],
            radius: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row with an arrow, read as one by TalkBack.
class _LinkRow extends StatelessWidget {
  const new({
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(RoamioRadii.base),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(child: child),
            const Icon(Icons.chevron_right, color: RoamioColors.slate),
          ],
        ),
      ),
    ),
  );
}
