import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';

/// Splits [total] in proportion to [weights]: each part is rounded down and
/// the leftover minor units go one at a time in list order, so the parts
/// always add up to [total] exactly (spec §6).
List<int> allocate(int total, List<int> weights) {
  if (weights.isEmpty || weights.any((w) => w < 0)) {
    throw ArgumentError.value(weights, 'weights', 'Need non-negative weights');
  }
  final sum = weights.fold(BigInt.zero, (a, w) => a + BigInt.from(w));
  if (sum == BigInt.zero) {
    throw ArgumentError.value(weights, 'weights', 'Weights sum to zero');
  }
  final big = BigInt.from(total);
  final parts = [
    for (final w in weights) (big * BigInt.from(w) ~/ sum).toInt(),
  ];
  var leftover = total - parts.fold(0, (a, b) => a + b);
  for (var i = 0; leftover > 0; i++, leftover--) {
    parts[i]++;
  }
  return parts;
}

/// Everything wrong with [tab]; empty when it can be split.
List<SplitProblem> problemsWith(TabSplit tab) {
  final amount = tab.amount.minor;
  final payers = tab.payers.map((p) => p.payer).toList();
  final percent = tab.percentBp;
  return [
    if (amount <= 0) SplitProblem.nonPositiveAmount,
    if (tab.participants.isEmpty) SplitProblem.noParticipants,
    if (tab.participants.toSet().length != tab.participants.length)
      SplitProblem.duplicateParticipant,
    if (payers.isEmpty) SplitProblem.noPayers,
    if (payers.toSet().length != payers.length) SplitProblem.duplicatePayer,
    if (tab.payers.any((p) => p.amountMinor <= 0))
      SplitProblem.nonPositivePayment,
    if (tab.payers.fold(0, (a, p) => a + p.amountMinor) != amount)
      SplitProblem.paymentsDontAddUp,
    if (percent != null) ...[
      if (!_sameMembers(percent.keys, tab.participants))
        SplitProblem.percentagesDontMatchParticipants,
      if (percent.values.any((bp) => bp <= 0))
        SplitProblem.nonPositivePercentage,
      if (percent.values.fold(0, (a, b) => a + b) != fullBasisPoints)
        SplitProblem.percentagesDontAddUp,
    ],
  ];
}

bool _sameMembers(Iterable<ParticipantId> a, List<ParticipantId> b) =>
    a.length == b.length && a.toSet().containsAll(b);

void _requireValid(TabSplit tab) {
  final problems = problemsWith(tab);
  if (problems.isNotEmpty) throw InvalidTabException(problems);
}

/// Each participant's share of [tab], in the tab's currency.
Map<ParticipantId, int> sharesFor(TabSplit tab) {
  _requireValid(tab);
  return _shares(tab.amount.minor, tab);
}

Map<ParticipantId, int> _shares(int amount, TabSplit tab) {
  final weights = [for (final p in tab.participants) tab.percentBp?[p] ?? 1];
  return Map.fromIterables(tab.participants, allocate(amount, weights));
}

/// What each person paid minus their share, in the tab's currency.
Map<ParticipantId, int> netsFor(TabSplit tab) {
  _requireValid(tab);
  return _nets(tab.amount.minor, tab);
}

Map<ParticipantId, int> _nets(int amount, TabSplit tab) {
  final paid = allocate(amount, [for (final p in tab.payers) p.amountMinor]);
  // Payers are unique (problemsWith), so each starts at what they paid.
  final nets = {
    for (var i = 0; i < tab.payers.length; i++) tab.payers[i].payer: paid[i],
  };
  _shares(amount, tab).forEach((p, share) {
    nets.update(p, (v) => v - share, ifAbsent: () => -share);
  });
  return nets;
}

/// Everyone's balance in [baseCurrency]: positive = owed money,
/// negative = owes money. Always sums to exactly zero.
///
/// A foreign tab is converted once as a whole (using its own [TabSplit.fxDate]
/// rates) and then split in the same proportions, so rounding can never
/// leave a paisa unaccounted for.
Map<ParticipantId, int> balancesFor({
  required List<TabSplit> tabs,
  required String baseCurrency,
  required FxRates Function(String date) ratesFor,
  List<Settlement> settlements = const [],
}) {
  final balances = <ParticipantId, int>{};
  void add(ParticipantId p, int delta) =>
      balances.update(p, (v) => v + delta, ifAbsent: () => delta);

  for (final tab in tabs) {
    _requireValid(tab);
    final base = ratesFor(tab.fxDate).convert(tab.amount, baseCurrency).minor;
    _nets(base, tab).forEach(add);
  }
  for (final s in settlements) {
    if (s.amount.currency != baseCurrency ||
        s.amount.minor <= 0 ||
        s.from == s.to) {
      throw ArgumentError.value(s, 'settlement', 'Invalid settlement');
    }
    add(s.from, s.amount.minor);
    add(s.to, -s.amount.minor);
  }
  return balances;
}
