import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/settlement_planner.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';

/// Property tests: invariants from spec §6 must hold for any valid trip.
void main() {
  const people = ['ari', 'ben', 'cy', 'dee', 'eli', 'pal:kiko', 'pal:lu'];
  const currencies = ['INR', 'EUR', 'JPY', 'KWD', 'THB', 'USD'];
  final rates = FxRates(
    date: '2026-10-27',
    usdRates: const {
      'INR': '84.1275',
      'EUR': '0.9213',
      'JPY': '151.37',
      'KWD': '0.3071',
      'THB': '35.62',
    },
  );

  List<T> pick<T>(Random r, List<T> from, int min) {
    final shuffled = [...from]..shuffle(r);
    return shuffled.take(min + r.nextInt(from.length - min + 1)).toList();
  }

  /// Splits [total] into [n] positive integers.
  List<int> randomParts(Random r, int total, int n) {
    final cuts = {for (var i = 0; i < n - 1; i++) 1 + r.nextInt(total - 1)};
    while (cuts.length < n - 1) {
      cuts.add(1 + r.nextInt(total - 1));
    }
    final points = [0, ...cuts.toList()..sort(), total];
    return [for (var i = 0; i < n; i++) points[i + 1] - points[i]];
  }

  TabSplit randomTab(Random r) {
    final participants = pick(r, people, 1);
    final payers = pick(
      r,
      people.where((p) => !p.startsWith('pal:')).toList(),
      1,
    );
    final amount = 100 + r.nextInt(5000000);
    final paid = randomParts(r, amount, payers.length);
    final percent = r.nextBool() && participants.length > 1;
    final bps = percent ? randomParts(r, 10000, participants.length) : null;
    return TabSplit(
      amount: Money(amount, currencies[r.nextInt(currencies.length)]),
      payers: [
        for (var i = 0; i < payers.length; i++) Payment(payers[i], paid[i]),
      ],
      participants: participants,
      percentBp: bps == null
          ? null
          : {
              for (var i = 0; i < participants.length; i++)
                participants[i]: bps[i],
            },
      fxDate: '2026-10-27',
    );
  }

  test('500 random trips: shares sum to the amount, balances to zero, '
      'and planned transfers settle everyone', () {
    final r = Random(20261027);
    for (var trip = 0; trip < 500; trip++) {
      final tabs = [for (var i = 0; i < 1 + r.nextInt(12); i++) randomTab(r)];

      for (final tab in tabs) {
        expect(problemsWith(tab), isEmpty, reason: 'generator made a bad tab');
        final shares = sharesFor(tab).values.reduce((a, b) => a + b);
        expect(shares, tab.amount.minor, reason: 'trip $trip shares');
        expect(netsFor(tab).values.reduce((a, b) => a + b), 0);
      }

      final base = currencies[r.nextInt(currencies.length)];
      final balances = balancesFor(
        tabs: tabs,
        baseCurrency: base,
        ratesFor: (_) => rates,
      );
      expect(
        balances.values.fold(0, (a, b) => a + b),
        0,
        reason: 'trip $trip balances in $base',
      );

      final transfers = planTransfers(balances, currency: base);
      final nonZero = balances.values.where((v) => v != 0).length;
      expect(transfers.length, lessThanOrEqualTo(max(0, nonZero - 1)));

      final after = balancesFor(
        tabs: tabs,
        settlements: [
          for (final t in transfers)
            Settlement(from: t.from, to: t.to, amount: t.amount),
        ],
        baseCurrency: base,
        ratesFor: (_) => rates,
      );
      expect(
        after.values.every((v) => v == 0),
        isTrue,
        reason: 'trip $trip should be all square after transfers',
      );
    }
  });
}
