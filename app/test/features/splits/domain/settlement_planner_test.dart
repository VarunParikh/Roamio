import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/settlement_planner.dart';

void main() {
  group('planTransfers', () {
    test('pays the spec §6 example back in two transfers', () {
      final transfers = planTransfers({
        'ari': 50000,
        'ben': 25000,
        'kiko': -75000,
      }, currency: 'INR');

      expect(transfers.map((t) => t.toString()), [
        'kiko → ari: 50000 INR',
        'kiko → ben: 25000 INR',
      ]);
    });

    test('matches the largest debtor with the largest creditor', () {
      final transfers = planTransfers({
        'a': 1000,
        'b': 300,
        'c': -900,
        'd': -400,
      }, currency: 'INR');

      expect(transfers.map((t) => t.toString()), [
        'c → a: 900 INR',
        'd → b: 300 INR',
        'd → a: 100 INR',
      ]);
    });

    test('breaks ties by order of appearance, so results are stable', () {
      final transfers = planTransfers({
        'a': 500,
        'b': 500,
        'c': -500,
        'd': -500,
      }, currency: 'EUR');

      expect(transfers.map((t) => t.toString()), [
        'c → a: 500 EUR',
        'd → b: 500 EUR',
      ]);
    });

    test('returns nothing when everyone is square', () {
      expect(planTransfers({'a': 0, 'b': 0}, currency: 'INR'), isEmpty);
      expect(planTransfers({}, currency: 'INR'), isEmpty);
    });

    test('refuses balances that do not sum to zero', () {
      expect(
        () => planTransfers({'a': 100, 'b': -99}, currency: 'INR'),
        throwsArgumentError,
      );
    });

    test('transfers expose their parts', () {
      final t = planTransfers({'a': 5, 'b': -5}, currency: 'INR').single;

      expect(t.from, 'b');
      expect(t.to, 'a');
      expect(t.amount.minor, 5);
      expect(t.amount.currency, 'INR');
    });
  });
}
