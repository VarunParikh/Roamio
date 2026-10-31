import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';

final _trip = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 10, 25),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  memberUids: const ['ari', 'bob'],
);

void main() {
  final today = DateTime(2026, 10, 29);

  Set<TabProblem> check({
    String amount = '1,200',
    String currency = 'THB',
    DateTime? date,
    String? category = 'food_dining',
    List<String> participants = const ['ari', 'bob'],
    DateTime? on,
    Map<String, String>? payers,
    Map<String, String>? percents,
  }) => tabProblems(
    adventure: _trip,
    amountText: amount,
    currency: currency,
    date: date ?? DateTime(2026, 10, 24),
    today: on ?? today,
    category: category,
    participants: participants,
    payerTexts: payers,
    percentTexts: percents,
  );

  group('payerTextsOf (item 5: someone removed while the form is open)', () {
    test('keeps only the people still on the squad', () {
      expect(payerTextsOf({'ari': '100', 'bob': '50'}, ['ari', 'cara']), {
        'ari': '100',
      });
    });

    test('keeps everything when everyone is still there', () {
      expect(payerTextsOf({'ari': '1'}, ['ari']), {'ari': '1'});
    });
  });

  group('fxDateFor (follow-up C4: a tab keeps the rates it used)', () {
    final oct29 = DateTime(2026, 10, 29);

    test('the day of the rates actually used, not the tab’s own day', () {
      // Rates for the 29th arrive at 06:00 India time; before then the
      // latest are the 28th's, and the tab keeps those for good.
      expect(fxDateFor(date: oct29, ratesDay: '2026-10-28'), '2026-10-28');
      expect(fxDateFor(date: oct29, ratesDay: '2026-10-29'), '2026-10-29');
    });

    test('the tab’s own day when no rates are known yet', () {
      expect(fxDateFor(date: oct29), '2026-10-29');
    });

    test('never a day after the tab', () {
      expect(fxDateFor(date: oct29, ratesDay: '2026-10-30'), '2026-10-29');
    });

    test('an edit keeps the old rate day unless the date changes', () {
      expect(
        fxDateFor(
          date: oct29,
          ratesDay: '2026-10-29',
          previous: (date: oct29, fxDate: '2026-10-28'),
        ),
        '2026-10-28',
      );
      expect(
        fxDateFor(
          date: DateTime(2026, 10, 30),
          ratesDay: '2026-10-30',
          previous: (date: oct29, fxDate: '2026-10-28'),
        ),
        '2026-10-30',
      );
    });

    test('a saved tab uses it', () {
      final tab = NewTab(
        description: '',
        category: 'food_dining',
        amountMinor: 100,
        currency: 'THB',
        date: oct29,
        payers: const [Payment('ari', 100)],
        participants: const ['ari'],
        fxDate: '2026-10-28',
      );
      expect(tab.fxDate, '2026-10-28');
      expect(tab.split.fxDate, '2026-10-28');
    });
  });

  group('tabProblems (spec UC-21)', () {
    test('a complete tab has no problems', () {
      expect(check(), isEmpty);
    });

    test('the amount must be a number above zero and at most 10,000,000', () {
      expect(check(amount: ''), {TabProblem.noAmount});
      expect(check(amount: 'abc'), {TabProblem.noAmount});
      expect(check(amount: '0'), {TabProblem.noAmount});
      expect(check(amount: '1.234'), {TabProblem.noAmount});
      expect(check(amount: '10,000,000'), isEmpty);
      expect(check(amount: '10,000,000.01'), {TabProblem.tooBig});
    });

    test('the date can be today but not later', () {
      expect(check(date: today), isEmpty);
      expect(check(date: DateTime(2026, 10, 29, 23)), isEmpty);
      expect(check(date: DateTime(2026, 10, 30)), {TabProblem.futureDate});
    });

    test('needs a category and at least one person sharing', () {
      expect(check(category: null), {TabProblem.noCategory});
      expect(check(participants: const []), {TabProblem.nobodySharing});
    });

    test('tabs close 7 days after the adventure ends (UC-11)', () {
      expect(check(on: DateTime(2026, 11)), isEmpty);
      expect(check(on: DateTime(2026, 11, 2)), {TabProblem.closed});
    });
  });

  group('split payment (UC-21: payers must total the amount)', () {
    test('payer amounts that add up are fine; blanks mean not paying', () {
      expect(check(payers: {'ari': '700', 'bob': '500', 'cara': ''}), isEmpty);
    });

    test('anything else is a problem', () {
      expect(check(payers: {'ari': '700', 'bob': '400'}), {
        TabProblem.paymentsDontAddUp,
      });
      expect(check(payers: {'ari': '1,200', 'bob': 'x'}), {
        TabProblem.paymentsDontAddUp,
      });
      expect(check(payers: {'ari': '', 'bob': ''}), {
        TabProblem.paymentsDontAddUp,
      });
      expect(check(payers: {'ari': '1,200', 'bob': '0'}), isEmpty);
    });

    test('payersFrom keeps only people who paid something', () {
      expect(
        payersFrom({
          'ari': '700',
          'bob': '',
          'cara': '0',
          'dan': '500',
        }, 'THB').map((p) => (p.payer, p.amountMinor)),
        [('ari', 70000), ('dan', 50000)],
      );
    });
  });

  group('custom % (UC-21: must total exactly 100.00%)', () {
    test('percentages that make 100% are fine', () {
      expect(check(percents: {'ari': '66.67', 'bob': '33.33'}), isEmpty);
    });

    test('anything else is a problem', () {
      expect(check(percents: {'ari': '60', 'bob': '30'}), {
        TabProblem.percentagesDontAddUp,
      });
      expect(check(percents: {'ari': '100', 'bob': '0'}), {
        TabProblem.percentagesDontAddUp,
      });
      expect(check(percents: {'ari': '100'}), {
        TabProblem.percentagesDontAddUp,
      });
    });

    test('parsePercent reads up to 2 decimals into basis points', () {
      expect(parsePercent('33.33'), 3333);
      expect(parsePercent(' 50 '), 5000);
      expect(parsePercent('100'), 10000);
      expect(parsePercent('0.01'), 1);
      for (final bad in ['', '33.333', '-5', '100.01', 'abc', '1,5']) {
        expect(parsePercent(bad), isNull, reason: bad);
      }
    });

    test('formatBasisPoints shows them back', () {
      expect(formatBasisPoints(3333), '33.33%');
      expect(formatBasisPoints(10000), '100%');
      expect(formatBasisPoints(5050), '50.5%');
      expect(formatBasisPoints(0), '0%');
    });

    test('equalPercents splits 100% with the spare going first', () {
      expect(equalPercents(['a', 'b', 'c']), {'a': 3334, 'b': 3333, 'c': 3333});
    });
  });

  group('NewTab', () {
    NewTab tab({String amount = '1,000.01'}) => NewTab(
      description: '  Dinner at Jay Fai ',
      category: 'food_dining',
      amountMinor: parseAmount(amount, 'THB')!,
      currency: 'THB',
      date: DateTime(2026, 10, 24),
      payers: [Payment('ari', parseAmount(amount, 'THB')!)],
      participants: const ['ari', 'bob', 'kiko'],
    );

    test('is one payer covering the whole amount, split equally', () {
      final split = tab().split;
      expect(problemsWith(split), isEmpty);
      expect(split.payers.single.payer, 'ari');
      expect(split.payers.single.amountMinor, 100001);
      expect(split.percentBp, isNull);
      expect(split.fxDate, '2026-10-24');
      expect(sharesFor(split).values.fold<int>(0, (a, b) => a + b), 100001);
    });

    test('your share is your equal part, or zero if not sharing', () {
      expect(tab(amount: '90').shareOf('bob'), 3000);
      expect(tab(amount: '90').shareOf('cara'), 0);
    });

    test('custom percentages and several payers split exactly', () {
      final split = NewTab(
        description: '',
        category: 'food_dining',
        amountMinor: 300000,
        currency: 'INR',
        date: DateTime(2026, 10, 24),
        payers: const [Payment('ari', 200000), Payment('ben', 100000)],
        participants: const ['ari', 'ben', 'kiko'],
        percentBp: const {'ari': 5000, 'ben': 2500, 'kiko': 2500},
      );
      // Spec §6 worked example.
      expect(split.shareOf('kiko'), 75000);
      expect(netsFor(split.split), {
        'ari': 50000,
        'ben': 25000,
        'kiko': -75000,
      });
    });
  });
}
