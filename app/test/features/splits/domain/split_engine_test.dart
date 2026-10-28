import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';

TabSplit inr(
  int amount, {
  required Map<ParticipantId, int> paid,
  required List<ParticipantId> participants,
  Map<ParticipantId, int>? percentBp,
  String currency = 'INR',
  String fxDate = '2026-10-27',
}) => TabSplit(
  amount: Money(amount, currency),
  payers: [for (final e in paid.entries) Payment(e.key, e.value)],
  participants: participants,
  percentBp: percentBp,
  fxDate: fxDate,
);

void main() {
  group('allocate', () {
    test('splits proportionally with the remainder in list order', () {
      expect(allocate(100, [1, 1, 1]), [34, 33, 33]);
      expect(allocate(101, [1, 1]), [51, 50]);
      expect(allocate(1000, [5000, 2500, 2500]), [500, 250, 250]);
      expect(allocate(1, [1, 1, 1]), [1, 0, 0]);
    });

    test('never overflows on large amounts and weights', () {
      final shares = allocate(9000000000000, [3333333333, 6666666667]);
      expect(shares.reduce((a, b) => a + b), 9000000000000);
    });

    test('rejects empty, negative or all-zero weights', () {
      expect(() => allocate(10, []), throwsArgumentError);
      expect(() => allocate(10, [1, -1]), throwsArgumentError);
      expect(() => allocate(10, [0, 0]), throwsArgumentError);
    });
  });

  group('problemsWith', () {
    test('accepts a valid equal split', () {
      expect(
        problemsWith(inr(3000, paid: {'ari': 3000}, participants: ['ari'])),
        isEmpty,
      );
    });

    test('flags a non-positive amount', () {
      expect(
        problemsWith(inr(0, paid: {'ari': 0}, participants: ['ari'])),
        contains(SplitProblem.nonPositiveAmount),
      );
    });

    test('flags missing or duplicate participants', () {
      expect(
        problemsWith(inr(100, paid: {'ari': 100}, participants: [])),
        contains(SplitProblem.noParticipants),
      );
      expect(
        problemsWith(
          inr(100, paid: {'ari': 100}, participants: ['ari', 'ari']),
        ),
        contains(SplitProblem.duplicateParticipant),
      );
    });

    test('flags payer problems', () {
      expect(
        problemsWith(inr(100, paid: {}, participants: ['ari'])),
        contains(SplitProblem.noPayers),
      );
      expect(
        problemsWith(inr(100, paid: {'ari': 60}, participants: ['ari'])),
        contains(SplitProblem.paymentsDontAddUp),
      );
      expect(
        problemsWith(
          inr(100, paid: {'ari': 100, 'ben': 0}, participants: ['ari']),
        ),
        contains(SplitProblem.nonPositivePayment),
      );
      final duplicatePayers = TabSplit(
        amount: Money(100, 'INR'),
        payers: [const Payment('ari', 50), const Payment('ari', 50)],
        participants: ['ari'],
        fxDate: '2026-10-27',
      );
      expect(
        problemsWith(duplicatePayers),
        contains(SplitProblem.duplicatePayer),
      );
    });

    test('flags percentages that do not total 100%', () {
      expect(
        problemsWith(
          inr(
            100,
            paid: {'ari': 100},
            participants: ['ari', 'ben'],
            percentBp: {'ari': 6000, 'ben': 3000},
          ),
        ),
        contains(SplitProblem.percentagesDontAddUp),
      );
    });

    test('flags non-positive percentages and ones that miss a participant', () {
      expect(
        problemsWith(
          inr(
            100,
            paid: {'ari': 100},
            participants: ['ari', 'ben'],
            percentBp: {'ari': 10000, 'ben': 0},
          ),
        ),
        contains(SplitProblem.nonPositivePercentage),
      );
      expect(
        problemsWith(
          inr(
            100,
            paid: {'ari': 100},
            participants: ['ari', 'ben'],
            percentBp: {'ari': 10000},
          ),
        ),
        contains(SplitProblem.percentagesDontMatchParticipants),
      );
    });
  });

  group('sharesFor', () {
    test('equal split puts the spare paisa on the first participant', () {
      expect(
        sharesFor(
          inr(10000, paid: {'a': 10000}, participants: ['a', 'b', 'c']),
        ),
        {'a': 3334, 'b': 3333, 'c': 3333},
      );
    });

    test('custom % split follows basis points', () {
      expect(
        sharesFor(
          inr(
            300000,
            paid: {'ari': 300000},
            participants: ['ari', 'ben', 'kiko'],
            percentBp: {'ari': 5000, 'ben': 2500, 'kiko': 2500},
          ),
        ),
        {'ari': 150000, 'ben': 75000, 'kiko': 75000},
      );
    });

    test('throws InvalidTabException listing the problems', () {
      expect(
        () => sharesFor(inr(100, paid: {'a': 50}, participants: ['a'])),
        throwsA(
          isA<InvalidTabException>()
              .having((e) => e.problems, 'problems', [
                SplitProblem.paymentsDontAddUp,
              ])
              .having((e) => e.toString(), 'message', contains('payments')),
        ),
      );
    });
  });

  group('netsFor', () {
    test('matches the spec §6 worked example', () {
      // ₹3,000 paid by Ari ₹2,000 + Ben ₹1,000; shares 50/25/25 with pal Kiko.
      final tab = inr(
        300000,
        paid: {'ari': 200000, 'ben': 100000},
        participants: ['ari', 'ben', 'kiko'],
        percentBp: {'ari': 5000, 'ben': 2500, 'kiko': 2500},
      );

      expect(netsFor(tab), {'ari': 50000, 'ben': 25000, 'kiko': -75000});
    });

    test('includes payers who are not participants', () {
      expect(netsFor(inr(1000, paid: {'ari': 1000}, participants: ['ben'])), {
        'ari': 1000,
        'ben': -1000,
      });
    });
  });

  group('balancesFor', () {
    final rates = FxRates(
      date: '2026-10-27',
      usdRates: const {'INR': '84', 'EUR': '0.8', 'JPY': '150'},
    );
    FxRates ratesFor(String date) => rates;

    test('sums tabs in the base currency', () {
      final balances = balancesFor(
        tabs: [
          inr(300000, paid: {'ari': 300000}, participants: ['ari', 'ben']),
          inr(10000, paid: {'ben': 10000}, participants: ['ari', 'ben']),
        ],
        baseCurrency: 'INR',
        ratesFor: ratesFor,
      );

      expect(balances, {'ari': 145000, 'ben': -145000});
    });

    test('converts foreign tabs once, then splits, so totals stay exact', () {
      // €10.00 = ₹1,050.00, split three ways.
      final balances = balancesFor(
        tabs: [
          inr(
            1000,
            currency: 'EUR',
            paid: {'ari': 1000},
            participants: ['ari', 'ben', 'kiko'],
          ),
        ],
        baseCurrency: 'INR',
        ratesFor: ratesFor,
      );

      expect(balances, {'ari': 70000, 'ben': -35000, 'kiko': -35000});
      expect(balances.values.reduce((a, b) => a + b), 0);
    });

    test('allocates multiple payers proportionally after conversion', () {
      // ¥1,000 paid ¥333 + ¥667 = ₹560.00
      final balances = balancesFor(
        tabs: [
          inr(
            1000,
            currency: 'JPY',
            paid: {'ari': 333, 'ben': 667},
            participants: ['kiko'],
          ),
        ],
        baseCurrency: 'INR',
        ratesFor: ratesFor,
      );

      expect(balances, {'ari': 18648, 'ben': 37352, 'kiko': -56000});
    });

    test('applies settlements: payer goes up, receiver goes down', () {
      final balances = balancesFor(
        tabs: [
          inr(10000, paid: {'ari': 10000}, participants: ['ari', 'ben']),
        ],
        settlements: [
          Settlement(from: 'ben', to: 'ari', amount: Money(3000, 'INR')),
        ],
        baseCurrency: 'INR',
        ratesFor: ratesFor,
      );

      expect(balances, {'ari': 2000, 'ben': -2000});
    });

    test('rejects settlements in another currency, to oneself, or ≤ 0', () {
      for (final bad in [
        Settlement(from: 'ben', to: 'ari', amount: Money(100, 'EUR')),
        Settlement(from: 'ben', to: 'ben', amount: Money(100, 'INR')),
        Settlement(from: 'ben', to: 'ari', amount: Money(0, 'INR')),
      ]) {
        expect(
          () => balancesFor(
            tabs: const [],
            settlements: [bad],
            baseCurrency: 'INR',
            ratesFor: ratesFor,
          ),
          throwsArgumentError,
        );
      }
    });

    test('is empty with no tabs', () {
      expect(
        balancesFor(tabs: const [], baseCurrency: 'INR', ratesFor: ratesFor),
        isEmpty,
      );
    });
  });
}
