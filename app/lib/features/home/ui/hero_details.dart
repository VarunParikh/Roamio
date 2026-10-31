import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/activity_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/budget/ui/budget_widget.dart';
import 'package:roamio/features/invites/data/invite_service.dart';
import 'package:roamio/features/invites/ui/invite_section.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/data/split_report_provider.dart';
import 'package:roamio/features/splits/domain/category_shares.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/ui/split_charts.dart';
import 'package:roamio/features/splits/ui/update_rates_button.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/sync/sync_banner.dart';
import 'package:roamio/features/sync/sync_controller.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/tab_approval.dart';
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
    void openSplit() => context.go(Routes.splitFor(a.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabsWaiting(adventure: a),
          BudgetWidget(adventure: a),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: openSplit,
              child: const Text('See split'),
            ),
          ),
          _DailySpend(adventure: a, onViewAll: openSplit),
          _TopCategory(adventure: a),
          _ExchangeRate(adventure: a),
          const Divider(color: RoamioColors.hairline),
          _SquadRow(adventure: a),
          _InviteShortcut(adventure: a),
          _ActivityRow(adventure: a),
        ],
      ),
    );
  }
}

/// Daily spend: the squad's, or the viewer's own when they only have personal
/// tabs. Before the trip it shows only if something has been spent already.
class _DailySpend extends ConsumerWidget {
  const new({required this.adventure, required this.onViewAll});

  final Adventure adventure;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final slate = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    final today = ref.watch(todayProvider);
    final started = adventure.statusOn(today) != AdventureStatus.upcoming;
    final report = ref.watch(splitReportProvider(adventure.id));
    final r = report.value;
    final spend = r == null
        ? const <DateTime, int>{}
        : r.byDay.isNotEmpty
        ? r.byDay
        : r.myByDay;
    if (!started && spend.isEmpty) return const SizedBox.shrink();

    Widget body() {
      if (r == null) {
        return report.hasError
            ? Text('We couldn’t load the spending.', style: slate)
            : const LinearProgressIndicator();
      }
      if (r.missingRates && r.balances.isEmpty) {
        return Text('Exchange rates aren’t available yet.', style: slate);
      }
      if (spend.isEmpty) return Text('No spending yet', style: slate);
      final end = adventure.endDate.isBefore(today) ? adventure.endDate : today;
      final start = adventure.startDate;
      return DayBars(
        days: allDays({
          ...spend,
          if (started) DateTime(start.year, start.month, start.day): 0,
          DateTime(end.year, end.month, end.day): 0,
        }),
        amountOf: (d) => spend[d] ?? 0,
        dayName: (d) => dayLabel(d, today),
        moneyOf: (m) => formatWithSymbol(ref, Money(m, r.currency)),
        visibleDays: 7,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: RoamioColors.hairline),
        Row(
          children: [
            Expanded(child: Text('Daily spend', style: text.titleMedium)),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
          ],
        ),
        body(),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A quick view for leads, who are the ones able to act on it (spec UC-21a).
class _TabsWaiting extends ConsumerWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    if (!adventure.isLead(myUid)) return const SizedBox.shrink();
    final tabs = ref.watch(tabsProvider(adventure.id)).value ?? const [];
    final count = tabsYouCanDecide(adventure, tabs, myUid).length;
    if (count == 0) return const SizedBox.shrink();
    final label = count == 1
        ? '1 tab waiting for approval'
        : '$count tabs waiting for approval';
    return _LinkRow(
      label: label,
      onTap: () => context.push('/adventures/${adventure.id}'),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: RoamioColors.slate,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

/// "Most on Food & Dining · 60%": the squad's, or the viewer's own when they
/// only have personal tabs.
class _TopCategory extends ConsumerWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(splitReportProvider(adventure.id)).value;
    if (r == null) return const SizedBox.shrink();
    final shares = topCategories(
      r.byCategory.isNotEmpty ? r.byCategory : r.myByCategory,
      top: 1,
    );
    if (shares.isEmpty) return const SizedBox.shrink();
    final top = shares.first;
    final id = top.category;
    if (id == null) return const SizedBox.shrink();
    final name =
        (ref.watch(categoriesProvider).value ?? const <Category>[])
            .where((c) => c.id == id)
            .firstOrNull
            ?.name ??
        id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Most on $name · ${top.percent}%',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// 1000 → "1,000".
String _grouped(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

/// "1 THB = ₹2.50" on a trip in another currency, at today's known rates.
class _ExchangeRate extends ConsumerWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(profileCurrencyProvider).value;
    final base = adventure.baseCurrency;
    if (mine == null || mine == base) return const SizedBox.shrink();
    final rates = ref.watch(fxRatesProvider(isoDate(ref.watch(todayProvider))));
    if (rates.isLoading) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme.bodyMedium;
    String? quote;
    final known = rates.value;
    if (known != null && known.hasRate(base) && known.hasRate(mine)) {
      final (:units, :value) = rateExample(known, from: base, to: mine);
      quote = '${_grouped(units)} $base = ${formatWithSymbol(ref, value)}';
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            quote ?? 'No exchange rate yet',
            style: quote == null
                ? text?.copyWith(color: RoamioColors.slate)
                : text,
          ),
        ),
        const UpdateRatesButton(),
      ],
    );
  }
}

/// Share invite, for a lead still alone in the squad. It's a plain button:
/// Home keeps a single chartreuse one.
class _InviteShortcut extends ConsumerStatefulWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  ConsumerState<_InviteShortcut> createState() => _InviteShortcutState();
}

class _InviteShortcutState extends ConsumerState<_InviteShortcut> {
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await shareInvite(ref, widget.adventure);
    } on InviteException catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.adventure;
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    if (!a.isLead(myUid) || a.memberUids.length > 1) {
      return const SizedBox.shrink();
    }
    final offline = ref.watch(isOfflineProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _busy || offline ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Invite your squad'),
          ),
          if (offline) const NeedsConnectionNote(),
        ],
      ),
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
