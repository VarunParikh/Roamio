import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';

/// A suggested "who pays whom" payment.
class Transfer {
  const new({required this.from, required this.to, required this.amount});

  final ParticipantId from;
  final ParticipantId to;
  final Money amount;

  @override
  String toString() => '$from → $to: ${amount.minor} ${amount.currency}';
}

/// Suggests at most n − 1 transfers that bring every [balances] entry to zero,
/// by repeatedly matching the largest debtor with the largest creditor.
/// Ties go to whoever appears first in [balances], so results are stable.
List<Transfer> planTransfers(
  Map<ParticipantId, int> balances, {
  required String currency,
}) {
  if (balances.values.fold(0, (a, b) => a + b) != 0) {
    throw ArgumentError.value(balances, 'balances', 'Must sum to zero');
  }
  final open = {
    for (final MapEntry(:key, :value) in balances.entries)
      if (value != 0) key: value,
  };
  final transfers = <Transfer>[];
  while (open.isNotEmpty) {
    final creditor = _extreme(open, (a, b) => a > b);
    final debtor = _extreme(open, (a, b) => a < b);
    final amount = open[creditor]! < -open[debtor]!
        ? open[creditor]!
        : -open[debtor]!;
    transfers.add(
      Transfer(from: debtor, to: creditor, amount: Money(amount, currency)),
    );
    for (final (p, delta) in [(creditor, -amount), (debtor, amount)]) {
      final left = open[p]! + delta;
      left == 0 ? open.remove(p) : open[p] = left;
    }
  }
  return transfers;
}

ParticipantId _extreme(
  Map<ParticipantId, int> open,
  bool Function(int a, int b) better,
) => open.entries
    .reduce((best, e) => better(e.value, best.value) ? e : best)
    .key;
