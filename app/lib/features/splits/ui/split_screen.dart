import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/budget/ui/budget_card.dart';
import 'package:roamio/features/home/ui/home_screen.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/splits/data/settlement_service.dart';
import 'package:roamio/features/splits/data/split_report_provider.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/splits/ui/export_sheet.dart';
import 'package:roamio/features/splits/ui/settle_sheet.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
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
    if (r == null && report.hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We couldn’t work out the split.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                ref
                  ..invalidate(tabsProvider(a.id))
                  ..invalidate(settlementsProvider(a.id));
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (r == null) return const Center(child: CircularProgressIndicator());

    final text = Theme.of(context).textTheme;
    final slate = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final symbol = ref.watch(countriesProvider).value?.symbolFor(r.currency);
    final labels = squadLabels(ref, a);
    String who(String id) => labels[id] ?? 'Left';
    final empty = r.totalSpend == 0 && r.balances.values.every((b) => b == 0);
    final settled =
        ref.watch(settlementsProvider(a.id)).value ?? const <SettlementEntry>[];

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
                        color: RoamioColors.coralText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BudgetCard(adventure: a),
        const SizedBox(height: 16),
        if (!empty && ref.watch(exportEnabledProvider))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  showExportSheet(context, ref, adventure: a, report: r),
              icon: const Icon(Icons.ios_share),
              label: const Text('Export'),
            ),
          ),
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
          Text('Who pays whom', style: text.titleMedium),
          const SizedBox(height: 4),
          if (r.transfers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Everyone is square.', style: text.bodyLarge),
            ),
          for (final t in r.transfers)
            _TransferRow(
              label: t.from == myUid
                  ? 'You pay ${who(t.to)}'
                  : t.to == myUid
                  ? '${who(t.from)} pays you'
                  : '${who(t.from)} pays ${who(t.to)}',
              amount: _money(ref, t.amount.minor, r.currency),
              onSettle: _maySettle(t.from, t.to)
                  ? () => _settle(r, t.from, t.to)
                  : null,
            ),
          const SizedBox(height: 20),
          if (settled.isNotEmpty) ...[
            Text('Payments recorded', style: text.titleMedium),
            const SizedBox(height: 4),
            for (final p in settled)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_paid(p.from, p.to), style: text.bodyLarge),
                        Text(
                          '${formatDay(parseIsoDate(p.date))} · '
                          '${_money(ref, p.amountMinor, p.currency)}',
                          style: slate,
                        ),
                      ],
                    ),
                  ),
                  if (_maySettle(p.from, p.to))
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo),
                      onPressed: () => _undo(p),
                    ),
                ],
              ),
            const SizedBox(height: 20),
          ],
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

  String get _me => ref.read(sessionFactsProvider).value?.uid ?? '';

  String _who(String id) => id == _me
      ? 'you'
      : squadLabels(ref, widget.adventure)[id] ?? 'Someone who left';

  /// "Kiko paid you", "You paid Ben Roy".
  String _paid(String from, String to) =>
      from == _me ? 'You paid ${_who(to)}' : '${_who(from)} paid ${_who(to)}';

  /// Spec UC-26a: either person in the payment, or a lead when a pal is
  /// involved (the security rules say the same).
  bool _maySettle(String from, String to) {
    final pals = {
      for (final p
          in ref.watch(palsProvider(widget.adventure.id)).value ??
              const <Pal>[])
        p.id,
    };
    return _me == from ||
        _me == to ||
        (widget.adventure.isLead(_me) &&
            (pals.contains(from) || pals.contains(to)));
  }

  Future<void> _settle(SplitReport r, String from, String to) async {
    final base = widget.adventure.baseCurrency;
    // Recorded in the trip's currency: the matching suggested transfer, or
    // what the two balances allow.
    final suggested =
        r.baseTransfers
            .where((t) => t.from == from && t.to == to)
            .firstOrNull
            ?.amount
            .minor ??
        [
          -(r.baseBalances[from] ?? 0),
          r.baseBalances[to] ?? 0,
        ].reduce((x, y) => x < y ? x : y);
    if (suggested <= 0) return;
    final amount = await showSettleSheet(
      context,
      title: _paid(from, to),
      suggestedMinor: suggested,
      currency: base,
      symbol: ref.read(countriesProvider).value?.symbolFor(base),
    );
    if (amount == null) return;
    await ref
        .read(settlementServiceProvider)
        .record(
          widget.adventure.id,
          from: from,
          to: to,
          amountMinor: amount,
          currency: base,
          date: isoDate(ref.read(todayProvider)),
        );
  }

  Future<void> _undo(SettlementEntry p) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo this payment?'),
        content: const Text(
          'It counts as owed again. The activity log keeps both.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (sure ?? false) {
      await ref.read(settlementServiceProvider).undo(widget.adventure.id, p.id);
    }
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

class _TransferRow extends StatelessWidget {
  const new({required this.label, required this.amount, this.onSettle});

  final String label;
  final String amount;

  /// Null when the viewer may not record this payment.
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyLarge),
                Text(amount, style: text.titleMedium),
              ],
            ),
          ),
          if (onSettle != null)
            TextButton(
              onPressed: onSettle,
              child: const Text('Mark as settled'),
            ),
        ],
      ),
    );
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('No adventures yet, so nothing to split.', style: slate),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push(newAdventureRoute),
            icon: const Icon(Icons.add),
            label: const Text('New Adventure'),
          ),
        ],
      );
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
                    style: text.bodySmall?.copyWith(
                      color: RoamioColors.coralText,
                    ),
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
