import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/splits/data/split_report_provider.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// The Split tab (spec UC-24 to UC-26): the active adventure's split, or
/// Overall when nothing is happening now. Headline first; details on
/// request; everything in the viewer's profile currency.
class SplitScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> {
  /// The adventure picked, or null for Overall; unset until someone picks.
  String? _picked;
  bool _hasPicked = false;

  void _pick(String? adventureId) => setState(() {
    _picked = adventureId;
    _hasPicked = true;
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final adventures = [...?ref.watch(myAdventuresProvider).value]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final active = adventures
        .where((a) => a.statusOn(today) == AdventureStatus.active)
        .firstOrNull;
    final selected = _hasPicked ? _picked : active?.id;
    final adventure = adventures.where((a) => a.id == selected).firstOrNull;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('Split', style: text.displayLarge),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Overall'),
                  selected: adventure == null,
                  onSelected: (_) => _pick(null),
                ),
                for (final a in adventures) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(a.name),
                    selected: a.id == adventure?.id,
                    onSelected: (_) => _pick(a.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (adventure == null)
            _Overall(adventures: adventures, onOpen: _pick)
          else
            _AdventureSplit(key: ValueKey(adventure.id), adventure: adventure),
        ],
      ),
    );
  }
}

String _money(WidgetRef ref, int minor, String currency, {bool sign = false}) {
  final text = formatWithSymbol(ref, Money(minor, currency));
  return sign && minor > 0 ? '+$text' : text;
}

class _AdventureSplit extends ConsumerStatefulWidget {
  const new({required this.adventure, super.key});

  final Adventure adventure;

  @override
  ConsumerState<_AdventureSplit> createState() => _AdventureSplitState();
}

class _AdventureSplitState extends ConsumerState<_AdventureSplit> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.adventure;
    final report = ref.watch(splitReportProvider(a.id));
    final r = report.value;
    if (r == null) return const Center(child: CircularProgressIndicator());

    final text = Theme.of(context).textTheme;
    final slate = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final symbol = ref.watch(countriesProvider).value?.symbolFor(r.currency);
    final labels = squadLabels(ref, a);
    String who(String id) => labels[id] ?? 'Left';
    final empty = r.totalSpend == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _showBase(r),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name, style: slate),
                  const SizedBox(height: 8),
                  Text(
                    headline(r.mine, r.currency, symbol),
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total spend ${_money(ref, r.totalSpend, r.currency)}',
                    style: slate,
                  ),
                  if (r.missingRates) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Shown in ${r.currency}: exchange rates aren’t '
                      'available yet.',
                      style: text.bodySmall?.copyWith(
                        color: RoamioColors.coral,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (empty) ...[
          Text(
            'No tabs yet in ${a.name}.',
            style: slate,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push('/adventures/${a.id}'),
            child: const Text('Open adventure'),
          ),
        ] else if (!_details)
          OutlinedButton(
            onPressed: () => setState(() => _details = true),
            child: const Text('See the details'),
          )
        else ...[
          _Section(
            title: 'Who pays whom',
            rows: r.transfers.isEmpty
                ? [('Everyone is square.', '')]
                : [
                    for (final t in r.transfers)
                      (
                        t.from == myUid
                            ? 'You pay ${who(t.to)}'
                            : t.to == myUid
                            ? '${who(t.from)} pays you'
                            : '${who(t.from)} pays ${who(t.to)}',
                        _money(ref, t.amount.minor, r.currency),
                      ),
                  ],
          ),
          _Section(
            title: 'Balances',
            rows: [
              for (final MapEntry(:key, :value) in r.balances.entries)
                (
                  key == myUid ? 'You' : who(key),
                  _money(ref, value, r.currency, sign: true),
                ),
            ],
          ),
          _Section(
            title: 'By category',
            rows: [
              for (final MapEntry(:key, :value) in _sorted(r.byCategory))
                (_categoryLabel(key), _money(ref, value, r.currency)),
            ],
          ),
          _Section(
            title: 'By day',
            rows: [
              for (final day
                  in r.byDay.keys.toList()..sort((x, y) => y.compareTo(x)))
                (
                  dayLabel(day, ref.watch(todayProvider)),
                  _money(ref, r.byDay[day]!, r.currency),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// UC-26: the figure in the trip's own currency, on tap.
  void _showBase(SplitReport r) {
    final base = widget.adventure.baseCurrency;
    if (base == r.currency) return;
    final mine = r.baseBalances[ref.read(sessionFactsProvider).value?.uid];
    final symbol = ref.read(countriesProvider).value?.symbolFor(base);
    showAuthMessage(context, 'In $base: ${headline(mine ?? 0, base, symbol)}');
  }

  List<MapEntry<String, int>> _sorted(Map<String, int> m) =>
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  String _categoryLabel(String id) {
    final c = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.id == id)
        .firstOrNull;
    return c == null ? id : '${c.emoji} ${c.name}';
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: 4),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: text.bodyLarge)),
                  Text(value, style: text.bodyLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Overall (UC-24): the viewer's share of spending across adventures; tap
/// one to open its split.
class _Overall extends ConsumerWidget {
  const new({required this.adventures, required this.onOpen});

  final List<Adventure> adventures;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final slate = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    final currency = ref.watch(profileCurrencyProvider).value ?? 'INR';
    if (adventures.isEmpty) {
      return Text('No adventures yet, so nothing to split.', style: slate);
    }
    final reports = {
      for (final a in adventures) a.id: ref.watch(splitReportProvider(a.id)),
    };
    final ready = reports.values.where((r) => r.hasValue).map((r) => r.value!);
    final total = ready
        .where((r) => r.currency == currency)
        .fold(0, (sum, r) => sum + r.myShare);
    final someMissing = ready.any((r) => r.currency != currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your share across adventures', style: slate),
                const SizedBox(height: 8),
                Text(_money(ref, total, currency), style: text.headlineMedium),
                if (someMissing) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Some adventures aren’t included: exchange rates aren’t '
                    'available yet.',
                    style: text.bodySmall?.copyWith(color: RoamioColors.coral),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final a in adventures)
          Card(
            key: ValueKey('overall-${a.id}'),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(a.name),
              subtitle: switch (reports[a.id]!.value) {
                final r? => Text(
                  headline(
                    r.mine,
                    r.currency,
                    ref.watch(countriesProvider).value?.symbolFor(r.currency),
                  ),
                ),
                null => const Text('…'),
              },
              trailing: switch (reports[a.id]!.value) {
                final r? => Text(
                  _money(ref, r.myShare, r.currency),
                  style: text.titleMedium,
                ),
                null => null,
              },
              onTap: () => onOpen(a.id),
            ),
          ),
      ],
    );
  }
}
