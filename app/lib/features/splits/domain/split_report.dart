import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/settlement_planner.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

/// The parts of a tab the split report needs.
class ReportTab {
  const new({
    required this.category,
    required this.date,
    required this.split,
    this.status = TabStatus.approved,
  });

  final String category;
  final DateTime date;
  final TabSplit split;
  final TabStatus status;
}

/// A "Mark as settled" payment, in the trip's currency (spec UC-26a).
class ReportSettlement {
  const new({
    required this.from,
    required this.to,
    required this.amountMinor,
    required this.date,
  });

  final ParticipantId from;
  final ParticipantId to;
  final int amountMinor;

  /// yyyy-mm-dd; its rates convert it, like a tab's.
  final String date;
}

/// One adventure's split, in [currency] (spec UC-25, UC-26).
class SplitReport {
  const new({
    required this.currency,
    required this.balances,
    required this.baseBalances,
    required this.mine,
    required this.myShare,
    required this.transfers,
    required this.baseTransfers,
    required this.byCategory,
    required this.byDay,
    required this.totalSpend,
    required this.missingRates,
    this.waitingCount = 0,
    this.waitingMyShare = 0,
    this.myByCategory = const {},
    this.myByDay = const {},
  });

  /// The viewer's profile currency, or the trip's when rates are missing.
  final String currency;

  /// Everyone's balance in [currency]: positive is owed, negative owes.
  final Map<ParticipantId, int> balances;

  /// The same in the trip's own currency, shown on tap.
  final Map<ParticipantId, int> baseBalances;

  /// The viewer's balance in [currency].
  final int mine;

  /// What the viewer's shares of approved tabs and their personal tabs add
  /// up to, in [currency].
  final int myShare;
  final List<Transfer> transfers;

  /// Who pays whom in the trip's currency, which is what gets recorded.
  final List<Transfer> baseTransfers;
  final Map<String, int> byCategory;
  final Map<DateTime, int> byDay;
  final int totalSpend;

  /// Some rates weren't there, so [currency] isn't the viewer's.
  final bool missingRates;

  /// Tabs waiting for an admin; they count towards nothing (spec UC-21a).
  final int waitingCount;

  /// What the viewer's share of those would be, in [currency]; left out for a
  /// tab whose rate is missing.
  final int waitingMyShare;

  /// [myShare] split by category and by day, personal tabs included. Only the
  /// viewer sees these; [byCategory] and [byDay] are the squad's.
  final Map<String, int> myByCategory;
  final Map<DateTime, int> myByDay;
}

/// Builds the split for [viewer]. Each tab converts at its own day's rates
/// ([ratesFor]); balances still sum to exactly zero (spec §6). If a rate
/// is missing it falls back to [baseCurrency] and sets
/// [SplitReport.missingRates].
SplitReport buildReport({
  required List<ReportTab> tabs,
  required String baseCurrency,
  required String viewerCurrency,
  required String viewer,
  required FxRates Function(String date) ratesFor,
  List<ReportSettlement> settlements = const [],
}) {
  // A tab the server will reject (checkTab soft-deletes it) can sit in the
  // offline cache for a moment; it's left out rather than breaking the
  // whole split (follow-up C5).
  bool isUsable(ReportTab t) =>
      problemsWith(t.split).isEmpty &&
      t.split.amount.minor <= maxTabMinor(t.split.amount.currency);
  final waitingCount = tabs.where((t) => t.status == TabStatus.waiting).length;
  final usable = [
    for (final t in tabs)
      if (isUsable(t) &&
          (t.status == TabStatus.approved || t.status == TabStatus.personal))
        t,
  ];
  // A personal tab's net is 0, so it doesn't move anyone's balance, but its
  // rate is still needed for the viewer's share (spec §6).
  final splits = [for (final t in usable) t.split];

  // Tabs convert inside the engine; settlements are added here, each at
  // its own day. Adding +s and −s keeps the zero sum (spec §6).
  Map<ParticipantId, int>? balancesIn(String currency) {
    try {
      final balances = balancesFor(
        tabs: splits,
        baseCurrency: currency,
        ratesFor: ratesFor,
      );
      for (final s in settlements) {
        final amount = ratesFor(s.date)
            .convert(Money(s.amountMinor, baseCurrency), currency)
            .minor;
        balances
          ..update(s.from, (v) => v + amount, ifAbsent: () => amount)
          ..update(s.to, (v) => v - amount, ifAbsent: () => -amount);
      }
      return balances;
    } on MissingRateException {
      return null;
    }
  }

  final base = balancesIn(baseCurrency);
  final viewers = viewerCurrency == baseCurrency
      ? base
      : _squareLikeBase(balancesIn(viewerCurrency), base);
  final currency = viewers != null ? viewerCurrency : baseCurrency;
  final balances = viewers ?? base;
  if (balances == null) {
    return SplitReport(
      currency: baseCurrency,
      balances: const {},
      baseBalances: const {},
      mine: 0,
      myShare: 0,
      transfers: const [],
      baseTransfers: const [],
      byCategory: const {},
      byDay: const {},
      totalSpend: 0,
      missingRates: true,
      waitingCount: waitingCount,
    );
  }

  final byCategory = <String, int>{};
  final byDay = <DateTime, int>{};
  final myByCategory = <String, int>{};
  final myByDay = <DateTime, int>{};
  var myShare = 0;
  var waitingMyShare = 0;
  for (final t in tabs) {
    if (t.status != TabStatus.waiting || !isUsable(t)) continue;
    try {
      final amount = ratesFor(t.split.fxDate)
          .convert(t.split.amount, currency)
          .minor;
      waitingMyShare += _shareIn(t.split, amount, viewer);
    } on MissingRateException {
      continue;
    }
  }
  for (final t in usable) {
    final amount = ratesFor(t.split.fxDate)
        .convert(t.split.amount, currency)
        .minor;
    final share = _shareIn(t.split, amount, viewer);
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    myShare += share;
    if (share != 0) {
      myByCategory.update(t.category, (v) => v + share, ifAbsent: () => share);
      myByDay.update(day, (v) => v + share, ifAbsent: () => share);
    }
    if (t.status == TabStatus.personal) continue;
    byCategory.update(t.category, (v) => v + amount, ifAbsent: () => amount);
    byDay.update(day, (v) => v + amount, ifAbsent: () => amount);
  }

  return SplitReport(
    currency: currency,
    balances: balances,
    baseBalances: base ?? const {},
    mine: balances[viewer] ?? 0,
    myShare: myShare,
    transfers: planTransfers(balances, currency: currency),
    baseTransfers: base == null
        ? const []
        : planTransfers(base, currency: baseCurrency),
    byCategory: byCategory,
    byDay: byDay,
    totalSpend: byCategory.values.fold(0, (a, b) => a + b),
    missingRates: currency != viewerCurrency,
    waitingCount: waitingCount,
    waitingMyShare: waitingMyShare,
    myByCategory: myByCategory,
    myByDay: myByDay,
  );
}

/// Settlements are recorded in the trip's currency, so converting each item
/// at its own day can leave someone who is square there a few cents off in
/// [viewer]'s currency. They show as square; the leftover goes to whoever
/// has the largest balance, so the total stays exactly zero (spec §6).
Map<ParticipantId, int>? _squareLikeBase(
  Map<ParticipantId, int>? viewer,
  Map<ParticipantId, int>? base,
) {
  if (viewer == null || base == null) return viewer;
  final out = Map.of(viewer);
  var leftover = 0;
  for (final id in out.keys.toList()) {
    if ((base[id] ?? 0) != 0) continue;
    leftover += out[id]!;
    out[id] = 0;
  }
  if (leftover != 0) {
    final largest = out.keys.reduce(
      (a, b) => (base[b] ?? 0).abs() > (base[a] ?? 0).abs() ? b : a,
    );
    out[largest] = out[largest]! + leftover;
  }
  return out;
}

/// [viewer]'s share of [tab] once its whole amount is [converted] minor
/// units, split in the tab's own proportions (spec §6).
int _shareIn(TabSplit tab, int converted, String viewer) {
  if (!tab.participants.contains(viewer) || converted == 0) return 0;
  final weights = [
    for (final p in tab.participants)
      tab.percentBp?[p] ?? (tab.percentBp == null ? 1 : 0),
  ];
  final parts = allocate(converted, weights);
  return parts[tab.participants.indexOf(viewer)];
}

/// "You're owed ₹500.00", "You owe ₹560.00" or "All square 🎉".
String headline(int mine, String currency, String? symbol) {
  final money = formatMoney(Money(mine.abs(), currency), symbol: symbol);
  if (mine > 0) return 'You’re owed $money';
  if (mine < 0) return 'You owe $money';
  return 'All square 🎉';
}
