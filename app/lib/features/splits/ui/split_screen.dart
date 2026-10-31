import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/router/app_router.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/budget/ui/budget_widget.dart';
import 'package:roamio/features/home/ui/home_screen.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/splits/data/settlement_service.dart';
import 'package:roamio/features/splits/data/split_report_provider.dart';
import 'package:roamio/features/splits/domain/category_shares.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/splits/ui/export_sheet.dart';
import 'package:roamio/features/splits/ui/settle_sheet.dart';
import 'package:roamio/features/splits/ui/split_charts.dart';
import 'package:roamio/features/splits/ui/update_rates_button.dart';
import 'package:roamio/features/splits/ui/who_pays_whom.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// The Split tab (spec UC-24 to UC-26): the active adventure's split, or
/// Overall when nothing is happening now. Headline first; details on
/// request; everything in the viewer's profile currency.
class SplitScreen extends ConsumerStatefulWidget {
  const new({this.adventureId, super.key});

  /// The adventure to open on; unknown or no longer visible ids are ignored.
  final String? adventureId;

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> {
  /// The adventure picked, or null for Overall; unset until someone picks.
  String? _picked;
  bool _hasPicked = false;

  @override
  void initState() {
    super.initState();
    _open(widget.adventureId);
  }

  @override
  void didUpdateWidget(SplitScreen old) {
    super.didUpdateWidget(old);
    if (widget.adventureId != old.adventureId) _open(widget.adventureId);
  }

  void _open(String? adventureId) {
    if (adventureId == null) return;
    _picked = adventureId;
    _hasPicked = true;
  }

  /// Picking a chip also moves the address, so opening the adventure that was
  /// first asked for later still counts as a change.
  void _pick(String? adventureId) {
    setState(() {
      _picked = adventureId;
      _hasPicked = true;
    });
    context.go(
      adventureId == null ? Routes.split : Routes.splitFor(adventureId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final adventures = [...?ref.watch(myAdventuresProvider).value]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final active = adventures
        .where((a) => a.statusOn(today) == AdventureStatus.active)
        .firstOrNull;
    final picked = adventures.where((a) => a.id == _picked).firstOrNull;
    // Overall is a pick too; only an id we can't show falls back to default.
    final adventure = _hasPicked && (_picked == null || picked != null)
        ? picked
        : active;

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

  /// The "•••" switch: figures in the trip's currency, not the viewer's.
  bool _inTripCurrency = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.adventure;
    final report = _inTripCurrency
        ? ref.watch(reportInProvider((a.id, a.baseCurrency)))
        : ref.watch(splitReportProvider(a.id));
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
    final people = squadPeople(ref, a);
    String who(String id) => people[id]?.name ?? 'Left';
    // Nothing counted for the squad: the tab list is the next step.
    final nothingShared =
        r.totalSpend == 0 && r.balances.values.every((b) => b == 0);
    // Rates were missing even for the trip's own currency.
    final unmeasured = r.missingRates && r.balances.isEmpty;
    final settled =
        ref.watch(settlementsProvider(a.id)).value ?? const <SettlementEntry>[];
    void openTabs() => context.push('/adventures/${a.id}');
    final myCurrency = ref.watch(profileCurrencyProvider).value;
    final switchTo = myCurrency == null || myCurrency == a.baseCurrency
        ? null
        : _inTripCurrency
        ? myCurrency
        : r.missingRates
        ? null
        : a.baseCurrency;
    final canExport = !nothingShared && ref.watch(exportEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(a.name, style: slate)),
                    if (canExport || switchTo != null)
                      PopupMenuButton<VoidCallback>(
                        tooltip: 'More options',
                        icon: const Icon(
                          Icons.more_horiz,
                          color: RoamioColors.slate,
                        ),
                        onSelected: (action) => action(),
                        itemBuilder: (_) => [
                          if (canExport)
                            PopupMenuItem(
                              value: () => showExportSheet(
                                context,
                                ref,
                                adventure: a,
                                report: r,
                              ),
                              child: const Text('Export'),
                            ),
                          if (switchTo != null)
                            PopupMenuItem(
                              value: () => setState(
                                () => _inTripCurrency = !_inTripCurrency,
                              ),
                              child: Text('Show in $switchTo'),
                            ),
                        ],
                      ),
                  ],
                ),
                if (unmeasured)
                  Text(
                    'We can’t work out this split yet: exchange rates aren’t '
                    'available.',
                    style: text.bodyMedium?.copyWith(
                      color: RoamioColors.coralText,
                    ),
                  )
                else ...[
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _money(ref, r.myShare, r.currency),
                          style: text.headlineMedium,
                        ),
                        TextSpan(text: ' spent by you', style: slate),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    headline(r.mine, r.currency, symbol),
                    style: text.titleMedium?.copyWith(
                      color: r.mine > 0
                          ? RoamioColors.mintText
                          : r.mine < 0
                          ? RoamioColors.coralText
                          : null,
                    ),
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
                if (r.missingRates || myCurrency != a.baseCurrency)
                  const UpdateRatesButton(),
                const SizedBox(height: 8),
                BudgetWidget(adventure: a),
              ],
            ),
          ),
        ),
        if (r.waitingCount > 0 && !nothingShared)
          TextButton(
            onPressed: openTabs,
            child: Text('${_tabCount(r.waitingCount)} waiting, not counted'),
          ),
        const SizedBox(height: 16),
        if (r.waitingCount > 0 && nothingShared)
          OutlinedButton(
            onPressed: openTabs,
            child: Text('${_tabCount(r.waitingCount)} waiting for approval'),
          )
        else if (nothingShared && r.myShare > 0 && !unmeasured) ...[
          // Only personal tabs: nothing to split, but they're still your spend.
          SpendByCategory(
            title: 'Your spend by category',
            totalLabel: 'Your spend',
            total: _money(ref, r.myShare, r.currency),
            shares: topCategories(r.myByCategory),
            nameOf: _categoryName,
            moneyOf: (m) => _money(ref, m, r.currency),
          ),
          const SizedBox(height: 24),
          const _Heading('Your spend by day'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DayBars(
                days: allDays(r.myByDay),
                amountOf: (d) => r.myByDay[d] ?? 0,
                dayName: formatDay,
                moneyOf: (m) => _money(ref, m, r.currency),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Only your personal tabs so far.',
            style: slate,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: openTabs,
            child: const Text('Open adventure'),
          ),
        ] else if (nothingShared) ...[
          if (!unmeasured) ...[
            Text(
              'No tabs yet in ${a.name}.',
              style: slate,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            onPressed: openTabs,
            child: const Text('Open adventure'),
          ),
        ] else ...[
          if (r.totalSpend > 0) ...[
            SpendByCategory(
              total: _money(ref, r.totalSpend, r.currency),
              shares: topCategories(r.byCategory),
              nameOf: _categoryName,
              moneyOf: (m) => _money(ref, m, r.currency),
            ),
            const SizedBox(height: 24),
          ],
          WhoPaysWhom(
            transfers: r.transfers,
            people: people,
            myUid: myUid,
            nameOf: who,
            amountOf: (t) => _money(ref, t.amount.minor, r.currency),
            mayAct: (t) => _maySettle(t.from, t.to),
            onAct: (t) => _settle(r, t.from, t.to),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() => _details = !_details),
            icon: const Icon(Icons.bar_chart),
            label: Text(_details ? 'Hide breakdown' : 'See detailed breakdown'),
          ),
          if (_details) ...[
            const SizedBox(height: 24),
            const _Heading('Balances'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final MapEntry(:key, :value) in r.balances.entries)
                      Padding(
                        key: ValueKey('balance-$key'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: MergeSemantics(
                          child: Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: PersonName(
                                    uid: key,
                                    person: people[key],
                                    name: key == myUid ? 'You' : who(key),
                                    style: text.bodyLarge,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _money(ref, value, r.currency, sign: true),
                                style: text.bodyLarge?.copyWith(
                                  color: value > 0
                                      ? RoamioColors.mintText
                                      : value < 0
                                      ? RoamioColors.coralText
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (settled.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _Heading('Payments recorded'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Column(
                    children: [
                      for (final p in settled)
                        Row(
                          children: [
                            PersonAvatar(
                              uid: p.from,
                              person: people[p.from],
                              radius: 14,
                            ),
                            const SizedBox(width: 4),
                            PersonAvatar(
                              uid: p.to,
                              person: people[p.to],
                              radius: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: MergeSemantics(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _paid(p.from, p.to),
                                      style: text.bodyLarge,
                                    ),
                                    Text(
                                      [
                                        formatDay(parseIsoDate(p.date)),
                                        _money(ref, p.amountMinor, p.currency),
                                      ].join(' · '),
                                      style: slate,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: _maySettle(p.from, p.to)
                                  ? IconButton(
                                      tooltip: 'Undo',
                                      icon: const Icon(Icons.undo),
                                      onPressed: () => _undo(p),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (r.totalSpend > 0) ...[
              const SizedBox(height: 24),
              const _Heading('All categories'),
              Card(
                child: Padding(
                  key: const ValueKey('all-categories'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      for (final MapEntry(:key, :value) in _sorted(
                        r.byCategory,
                      ))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: MergeSemantics(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _categoryLabel(key),
                                    style: text.bodyLarge,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _money(ref, value, r.currency),
                                  style: text.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _Heading('Spend by day'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DayBars(
                    days: allDays(r.byDay),
                    amountOf: (d) => r.byDay[d] ?? 0,
                    dayName: formatDay,
                    moneyOf: (m) => _money(ref, m, r.currency),
                  ),
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }

  /// "1 tab", "2 tabs".
  String _tabCount(int n) => n == 1 ? '1 tab' : '$n tabs';

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
      people: _SettlePeople(from: from, to: to, adventure: widget.adventure),
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

  List<MapEntry<String, int>> _sorted(Map<String, int> m) =>
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  Category? _category(String id) =>
      (ref.watch(categoriesProvider).value ?? const <Category>[])
          .where((c) => c.id == id)
          .firstOrNull;

  String _categoryName(String id) => _category(id)?.name ?? id;

  String _categoryLabel(String id) {
    final c = _category(id);
    return c == null ? id : '${c.emoji} ${c.name}';
  }
}

/// Who a payment being recorded is between, with their pictures.
class _SettlePeople extends ConsumerWidget {
  const new({required this.from, required this.to, required this.adventure});

  final String from;
  final String to;
  final Adventure adventure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionFactsProvider).value?.uid;
    final people = squadPeople(ref, adventure);
    Widget person(String id) => Flexible(
      child: PersonName(
        uid: id,
        person: people[id],
        name: id == me ? 'You' : null,
      ),
    );
    return Row(
      children: [
        person(from),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 16, color: RoamioColors.slate),
        ),
        person(to),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
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
                if (someMissing && total == 0)
                  Text('Not available yet', style: text.headlineMedium)
                else
                  Text(
                    _money(ref, total, currency),
                    style: text.headlineMedium,
                  ),
                if (someMissing) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Some adventures aren’t included: exchange rates aren’t '
                    'available yet.',
                    style: text.bodySmall?.copyWith(
                      color: RoamioColors.coralText,
                    ),
                  ),
                  const UpdateRatesButton(),
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
