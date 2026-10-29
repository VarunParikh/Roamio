import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
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
  }) => tabProblems(
    adventure: _trip,
    amountText: amount,
    currency: currency,
    date: date ?? DateTime(2026, 10, 24),
    today: on ?? today,
    category: category,
    participants: participants,
  );

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

  group('NewTab', () {
    NewTab tab({String amount = '1,000.01'}) => NewTab(
      description: '  Dinner at Jay Fai ',
      category: 'food_dining',
      amountMinor: parseAmount(amount, 'THB')!,
      currency: 'THB',
      date: DateTime(2026, 10, 24),
      payer: 'ari',
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
  });
}
